# Draws Page Listing
# Passed a List containing:
# Refs,
# Titles,
# Selected,
# Active

class PageList

  include Colour

  def initialize
    @buffer = String.new
    @colours = default_colours
  end

  def default_colours
    {
      ref: {
        act_sel:  :green,
        selected: :red,
        active:   :blue,
        default:  :black
      },
      title:  {
        act_sel:  :green,
        selected: :red,
        active:   :blue,
        default:  :black
      }
    }
  end

  def draw page
    @page = page
    buffer = String.new
    @page[:size].times do |id|
      buffer << format(:ref, id)
      buffer << format(:title, id)
    end
    buffer
  end

  def format attr, id
    colour = @colours[attr][select_format(id)]
    colour.to_s
#    colorize(attr, colour)
  end

  def active_selected
    @page[:selected] == @page[:active]
    return @page[:selected]
    nil
  end

  def active
    @page[:active]
  end

  def selected
    @page[:selected]
  end

  def select_format id
    case id
    when active_selected then :act_sel
    when selected then :selected
    when active then :active
    else
      :default
    end
  end
end
