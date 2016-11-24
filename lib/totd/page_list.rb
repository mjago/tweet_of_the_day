# Draws Page Listing
# Passed a List containing:
# Refs,
# Titles,
# Selected,
# Active

require 'colorize'

class PageList

  include Colour

  def initialize
    @buffer = String.new
  end

  def draw page
    @page = page
    buffer = String.new
    @page[:size].times do |id|
      buffer << format(:ref, id)
      buffer << ' '
      buffer << format(:title, id)
      buffer << "\n\r"
    end
    buffer
  end

  private

  def format attr, id
    colour = list_colours[attr][select_format(attr, id)]
    case attr
    when :ref
      @page[:refs][id].to_s.colorize(colour)
    when :title
      @page[:titles][id].colorize(colour)
    end
  end

  def active_selected
    return @page[:selected] if @page[:selected] == @page[:active]
    nil
  end

  def active
    @page[:active]
  end

  def selected
    @page[:selected]
  end

  def local id
    @page[:locals][id]
  end

  def select_format attr, id
    fmt = case id
          when active_selected then :act_sel
          when selected then :selected
          when active then :active
          else
            :default
          end
    return :local if attr == :ref && local(id)
    fmt
  end
end
