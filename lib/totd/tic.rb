class Tic

  def initialize
    Thread.abort_on_exception = true
    @flag = false
    init_processes
    run
  end

  def init_processes
    @processes =
      { process: {
          timeout: 5,
          value:   0 },
        playing_time: {
          timeout: 1,
          value:   0 },
        ended: {
          timeout: 1,
          value:   0 }
      }
  end

  def inc_processes
    @processes.each { |process| process[:value] += 1 }
  end

  def kill
    Thread.kill(@th_tic) if @th_tic
  end

  def timeout? type
    @processes[type]
    return unless @processes[type][:value] > @processes[type][:timeout]
    @processes[type][:value] = 0
    true
  end

  def process
    timeout? :process
  end

  def playing_time
    timeout? :playing_time
  end

  def ended
    timeout? :ended
  end

  def run
    Thread.abort_on_exception = true
    @th_tic = Thread.new do
      loop do
        sleep 0.2
        @processes[:process][:value] += 1
        @processes[:playing_time][:value] += 1
        @processes[:ended][:value] += 1
        @flag = true
      end
    end
  end

  def toc
    ret_val = @flag
    @flag = false
    ret_val
  end
end
