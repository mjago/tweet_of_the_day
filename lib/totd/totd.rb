# encoding: utf-8

require 'io/console'
require 'yaml'
require 'colorize'
require 'net/http'
require 'pty'

class TweetOfTheDay

  ROOT            = File.expand_path '~/'
  HERE            = File.dirname(__FILE__)
  CONFIG_DIR      = '.tweet_of_the_day'.freeze
  CONFIG_NAME     = 'config.yml'.freeze
  TOTD            = File.join ROOT, CONFIG_DIR
  VERSION         = File.join HERE, '..','..','VERSION'
  DEFAULT_CONFIG  = File.join HERE, '..','..',CONFIG_NAME
  CONFIG          = File.join TOTD,CONFIG_NAME
  UPDATE_INTERVAL = 604800
  AUDIO_DIRECTORY = 'audio'.freeze
  RSS_DIRECTORY   = 'rss'.freeze

  def initialize
    setup
    @feed = ReadFeed.new
    @content = String.new
    @programs = @feed.read_rss
    mark_locals
    @selected = 0
    @titles_count = @programs.length
    sort_titles
    load_config
#    STDIN.echo = false
#    STDIN.raw!
    run
  end

  def mark_locals
    @programs.each_with_index do |prg, idx|
      if have_locally?(prg[:title])
        @programs[idx][:have_locally] = true
      else
        @programs[idx][:have_locally] = false
      end
    end
  end

  def sort_titles
    @sorted_titles = @programs.collect { |pr| pr[:title] }
    @sorted_titles.sort_by!(&:downcase) unless @sort == :age
  end

  def setup
    @start_time = Time.now
    totd = TOTD
    audio = File.join totd, AUDIO_DIRECTORY
    rss = File.join totd, RSS_DIRECTORY
    Dir.mkdir totd unless Dir.exist? totd
    Dir.mkdir audio unless Dir.exist? audio
    return if Dir.exist?(rss)
    Dir.mkdir rss
  end

  def do_configs
    init_theme
    set_dimensions
    init_line_count
    @sort = @config[:sort]
  end

  def load_config
    create_config unless File.exist? CONFIG
    @config = YAML.load_file(CONFIG)
    do_configs
  end

  def create_config
    @config = YAML.load_file(DEFAULT_CONFIG)
    save_config
  end

  def save_config
    File.open(CONFIG, 'w') { |f| f.write @config.to_yaml}
  end

  def init_theme
    theme = @config[:colour_theme]
    @selection_colour = @config[theme][:selection_colour]
    @count_sel_colour = @config[theme][:count_sel_colour]
    @count_colour     = @config[theme][:count_colour]
    @text_colour      = @config[theme][:text_colour]
    @system_colour    = @config[theme][:system_colour]
  end

  def init_line_count
    @line_count = @page_height
  end

  def filename_from_title title
    temp = title.gsub(/[^0-9a-z ]/i, '').tr(' ', '_').strip + '.mp3'
    File.join TOTD, AUDIO_DIRECTORY, temp.downcase
  end

  def iot_print x, col = @text_colour, now = false
    content = String.new
      content << x.colorize(col) if @config[:colour]
      content << x unless @config[:colour]
      unless now
        @content << content
      else
        $stdout << content
      end
  end

  def iot_puts x = '', col = @text_colour, now = false
    iot_print x, col, now
    iot_print "\n\r", now
  end

  def clear
    system('clear') || system('cls')
  end

  def clear_content
    @content.clear
  end

  def render
    clear
    $stdout << @content
  end

  def dev_mode?
    ENV['TOTD'] == 'development'.freeze
  end

  def puts_title colour
    iot_puts %q{Tweet of the Day}.freeze, colour, :now
  end

  def window_height
    $stdout.winsize.first
  end

  def window_width
    $stdout.winsize[1]
  end

  def set_dimensions
    set_height
    set_width
  end

  def set_height
    height = window_height
    while(((height - 2) % 10) != 0) ; height -= 1 ; end
    height = 10 if height < 10
    @page_height = height if(@config[:page_height] == :auto)
    @page_height = @config[:page_height] unless(@config[:page_height] == :auto)
  end

  def set_width
    width = window_width
    while(width % 10 != 0) ; width -=1 ; end
    width = 20 if width < 20
    @page_width = width - 1 if(@config[:page_width]  == :auto)
    @page_width = @config[:page_width] unless(@config[:page_width]  == :auto)
  end

  def redraw
    @line_count -= @page_height
    draw_page
  end

  def draw_page
    clear_content
    if @line_count <= @titles_count
      @line_count.upto(@line_count + @page_height - 1) do |idx|
        if idx < @titles_count
          iot_print "> " if(idx == @selected) unless @config[:colour]
          show_count_maybe idx
          iot_puts @sorted_titles[idx], @selection_colour if (idx == @selected)
          iot_puts @sorted_titles[idx], @text_colour   unless(idx == @selected)
        end
      end
    else
      @line_count = 0
      0.upto(@page_height - 1) do |idx|
        iot_print "> ", @selection_colour if(idx == @selected)
        show_count_maybe(idx) unless @sorted_titles[idx].nil?
        iot_puts @sorted_titles[idx], @text_colour unless @sorted_titles[idx].nil?
      end
    end
    @line_count += @page_height
    print_playing_maybe
    render
  end

  def show_count_maybe idx
    if have_locally?(@sorted_titles[idx])
      iot_print idx_format(idx), @count_sel_colour if @config[:show_count]
    else
      iot_print idx_format(idx), @count_colour if @config[:show_count]
    end
    iot_print ' '
  end

  def have_locally? title
    filename = filename_from_title(title)
    File.exist?(filename) ? true : false
  end

  def idx_format idx
    sprintf("%03d", idx + 1)
  end

  def print_playing_maybe
    if @playing
      print_playing unless @paused
      print_paused if @paused
      print_play_time
    elsif @started.nil?
      @started = true
      instructions
    end
  end

  def instructions
    iot_print "Type", @system_colour
    iot_print " h ", :light_green
    iot_print "for instructions", @system_colour
  end

  def check_tic
    return unless @tic.toc
#    check_process if @tic.process
#    check_finished if @tic.ended
    return unless @info.nil?
    return unless @help.nil?
    check_playing_time if @tic.playing_time
   end

  def run
    ip = ''
    @tic = Tic.new
    @key = KeyboardEvents.new
    redraw
    loop do
      loop do
        ip = @key.read
        break unless ip == :no_event
        check_tic
        do_events
      end
      reset_info_maybe ip
      do_action ip
      do_events
    end
  end

  def do_events
    sleep 0.003
    sleep 0.1
  end

  def check_playing_time
    return unless @playing
    return unless @play_time.changed? unless use_mpg123?
    redraw
  end

  def reset_info_maybe ip
    @info = nil unless ip == :info
    @help = nil unless ip == :help
  end

  def do_action ip
    case ip
    when :pause, :forward, :rewind, :list_key, :page_forward, :page_back,
         :previous, :next, :play, :sort_key, :theme_toggle, :update_key,
         :info, :help, :quit_key, :search, :download_key, :enqueue,
         :next_program, :shuffle_key
      self.send ip
    end
  end

  def list_key
    if top_or_end?
      if top_or_end_title_focus
        if top_selected
          list_end
        else
          list_top
        end
      else
        draw_by_title title_focus
      end
    else
      store_selected
      list_top_or_end
    end
  end

  def draw_by_title title
    @selected, @line_count = sort_selected(title)
    redraw
  end

  def sort_selected title
    @sorted_titles.each_with_index do |st, sel|
      if st == title
        return sel, get_line_count(sel)
      end
    end
  end


  def top_or_end?
    top_selected || end_selected
  end

  def top_selected
    @selected == 0
  end

  def end_selected
    @selected == @titles_count - 1
  end

  def list_top_or_end
    @list_top = @list_top? nil : true
    if @list_top
      list_top
    else
      list_end
    end
  end

  def list_top
    @selected = 0
    draw_selected
  end

  def list_end
    @selected = @titles_count - 1
    draw_selected
  end

  def title_focus
    @playing ? @playing : (@sorted_titles[@last_selected || 0])
  end

  def top_or_end_title_focus
    top_title_focus || end_title_focus
  end

  def top_title_focus
    title_focus == @sorted_titles.first
  end

  def end_title_focus
    title_focus == @sorted_titles.last
  end

  def store_selected
    @last_selected = @selected
  end

  def previous
    return if @selected <= 0
    @selected -= 1
    draw_selected
  end

  def next
    return if @selected >= (@titles_count - 1)
    @selected += 1
    draw_selected
  end

  def page_forward
    return unless @line_count < @titles_count
    @selected = @line_count
    draw_selected
  end

  def page_back
    @selected = @line_count - @page_height * 2
    @selected = @selected < 0 ? 0 : @selected
    draw_selected
  end

  def draw_selected
    @line_count = get_line_count(@selected)
    redraw
  end

  def get_line_count idx
    idx += 1
    while idx % @page_height != 0
      idx += 1
    end
    idx
  end

  def info
    clear_content
    case @info
    when nil
      prg = select_program @sorted_titles[@selected]
      print_subtitle prg
#    when 1
#      prg = select_program @sorted_titles[@selected]
#      print_info prg
#    when 2
#      prg = select_program @sorted_titles[@selected]
#      print_guests prg
    else
      redraw
      @info = nil
      return
    end
    render
  end

  def select_program title
    @programs.map{|pr| return pr if(pr[:title].strip == title.strip)}
    nil
  end

  def print_subtitle prg
    clear
    puts_title @system_colour
    justify(prg[:description].gsub(/\s+/, ' '))[0].map{|x| iot_puts x}
    print_program_details prg
    @info = 1
    @page_count = 1
  end

  def justify info
    pages = [[],[]]
    page = 0
    top = 0
    bottom = @page_width
    loop do
      shift = top_space info[top..bottom]
      top = top + shift
      bottom = bottom + shift
      loop do
        idx = info[top..bottom].index("\n")
        if idx
          pages[page] << info[top..top + idx]
          page = 1
          bottom = top + idx + @page_width + 1
          top = top + idx + 1
        else
          break if bottom_space? info[bottom]
          bottom -= 1
        end
      end
      if last_line? info, top
        pages[page] << info[top..-1].strip
        break
      end
      pages[page] << info[top..bottom]
      top = bottom
      bottom = bottom + @page_width
    end
    pages
  end

  def top_space info
    info.length - info.lstrip.length
  end

  def bottom_space? bottom
    bottom == ' '
  end

  def last_line? info, top
    info[top..-1].length < @page_width
  end

  def print_program_details prg
    iot_puts "\nDate Broadcast: #{prg[:date]}"
    iot_puts "Duration:       #{prg[:duration].to_i/60} mins"
    iot_puts "Availability:   " +
             (prg[:have_locally] ? 'Downloaded' : 'Requires Download')
  end

  def print_info prg
    info = prg[:summary].gsub(/\s+/, ' ')
    count = 1
    justify(reformat(info))[0].each do |x|
      if (count > (@page_count - 1) * @page_height) &&
         (count <= @page_count * @page_height)
        iot_puts x
      end
      count += 1
    end
    if count <= @page_count * @page_height + 1
      @info = justify(reformat(info))[1] == [] ? -1 : 2
    else
      @page_count += 1
    end
  end

  def play
    title = @sorted_titles[@selected]
    playing = @playing
    prg = select_program(title)
    download prg unless playing
    download prg if playing && (playing != title)
    kill_audio
    return unless (! playing) || (playing != title)
    run_program prg
    redraw
  end

  def download prg
    return if prg[:have_locally]
    retries = 0
    clear_content
    iot_puts "Fetching #{prg[:title]}", @system_colour
    render
    10.times do
      begin
        res = Net::HTTP.get_response(URI.parse(prg[:url]))
      rescue SocketError => e
        print_error_and_delay "Error: Failed to connect to Internet! (#{e.class})"
        render
        @no_play = true
        break
      end
      case res
      when Net::HTTPFound
        iot_puts 'redirecting...', @system_colour
        render
        @doc = Oga.parse_xml(res.body)
        redirect = @doc.css("body p a").text
        break if download_audio(prg, redirect)
        sleep 2
      else
        print_error_and_delay 'Error! Failed to be redirected!'
        render
        @no_play = true
      end
      retries += 1
    end
    if retries >= 10
      print_error_and_delay "Max retries downloading #{prg[:title]}"
      render
      @no_play = true
    end
  end

  def download_audio(program, addr)
    res = Net::HTTP.get_response(URI.parse(addr))
    case res
    when Net::HTTPOK
      File.open(filename_from_title(program[:title]) , 'wb') do |f|
        iot_puts "writing #{File.basename(filename_from_title(program[:title]))}", @system_colour
        render
        sleep 0.2
        f.print(res.body)
        iot_puts " written.", @system_colour
        render
      end
      program[:have_locally] = true
    else
      iot_puts 'Download failed. Retrying...', @system_colour
      render
      nil
    end
  end

  def kill_audio
    loop do
      Thread.kill(@player_th) if @player_th
      return unless @playing
      begin
        break unless @pid.is_a?(Integer)
        Process.kill('QUIT', @pid)
        _, status = Process.wait2 @pid
        break if status.exited?
      rescue Errno::ESRCH
        break
      end
      sleep 0.2
    end
    reset
  end

  def run_program prg
    unless @no_play
      @playing = prg[:title]
      player = player_cmd.split(' ').first
      unknown_player(player) unless which(File.basename player)
      window_title prg[:title]
      cmd = player_cmd + ' ' + filename_from_title(@playing)
      @messages = []
      init_countdown prg[:duration].to_i
      @player_th = Thread.new do
        buf = ''
        p_out, @p_in, @pid = PTY.spawn(cmd)
        sleep 1
        count = 0
        loop do
          unless use_mpg123?
            sleep 1
          else
            x = p_out.getc unless p_out.eof?
            if(((count >= 6) && (count <= 10)) ||
               ((count > 15) && (count < 21))   )
              buf << x
              count += 1
            elsif(((count == 0)  && (x == 'T'))  ||
                  ((count == 1)  && (x == 'i'))  ||
                  ((count == 2)  && (x == 'm'))  ||
                  ((count == 3)  && (x == 'e'))  ||
                  ((count == 4)  && (x == ':'))  ||
                  ((count == 5)  && (x == ' '))  ||
                  ((count >= 12) && (count <= 15)))
              count += 1
            elsif count == 11
              @running_time = buf
              buf = ''
              count += 1
            elsif count == 21
              @remaining_time = buf
              buf = ''
              count = 0
              sleep 0.3
              p_out.flush
            else
              count = 0
              sleep 0.001
            end
          end
        end
      end
    end
    @no_play = nil
  end

  def player_cmd
    if use_mpg123?
      "mpg123 -Cvk#{pre_delay}"
    else
      get_player
    end
  end

  def use_mpg123?
    @config[:mpg_player] == :mpg123
  end

  def pre_delay
    160.to_s
  end

  def quit_key
    kill_audio
    quit
  end

  def quit code = 0
    @key.kill if @key
    @tic.kill if @tic
    sleep 0.5
    STDIN.echo = true
    STDIN.cooked!
    puts "\n\n#{@error_msg}" if @error_msg
    puts 'Quitting...'.freeze
    sleep 0.5
    exit code
  end

  def get_player
    return 'afplay' if @config[:mpg_player] == :afplay
    @config[:mpg_player].to_s
  end

  # Cross-platform way of finding an executable in the $PATH.
  #
  #   which('ruby') #=> /usr/bin/ruby

  def which(cmd)
    exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      exts.each { |ext|
        exe = File.join(path, "#{cmd}#{ext}")
        return exe if File.executable?(exe) && !File.directory?(exe)
      }
    end
    return nil
  end

  def unknown_player cmd
    @error_msg = "Error: Unknown MPG Player: #{cmd}\r"
    quit 1
  end

  def window_title title = ''
    STDOUT.puts "\"\033]0;#{title}\007"
  end

  def init_countdown(duration)
    @play_time = PlayTime.new(duration) unless use_mpg123?
  end

  def print_playing
    iot_print("Playing: ", @count_colour)
  end

  def print_paused
    iot_print("Paused: ", @count_colour)
  end

  def print_play_time
    if use_mpg123?
      iot_print(@playing, @selection_colour)
      iot_print(' (' + @running_time, @selection_colour) unless @running_time.nil?
      iot_print(' / ' + @remaining_time, @selection_colour) unless @remaining_time.nil?
      iot_puts(')', @selection_colour) unless @running_time.nil?
    else
      iot_puts(@playing + @play_time.read, @selection_colour)
    end
  end

  def print_playing_maybe
    if @playing
      print_playing unless @paused
      print_paused if @paused
      print_play_time
    elsif @started.nil?
      @started = true
      instructions
    end
  end

  def reset
    @pid = nil
    @playing = nil
    @paused = nil
    window_title
    redraw
  end

  def control_play?
    @playing && use_mpg123?
  end

  def write_player str
    begin
      @p_in.puts str
    rescue Errno::EIO
      kill_audio
      reset
    end
  end

  def forward
    return unless control_play?
    write_player ":"
    @play_time.forward unless use_mpg123?
  end

  def rewind
    return unless control_play?
    write_player ";"
    @play_time.rewind unless use_mpg123?
  end

  def pause
    return unless control_play?
    @paused = @paused ? false : true
    @play_time.pause if @paused unless use_mpg123?
    @play_time.unpause unless @paused unless use_mpg123?
    write_player " "
    redraw
  end

end
