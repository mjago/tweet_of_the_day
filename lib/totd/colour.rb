module Colour

  def list_colours
    {
      ref: {
        act_sel:  :red,
        selected: :green,
        active:   :blue,
        default:  :black
      },
      title:  {
        act_sel:  :red,
        selected: :green,
        active:   :blue,
        default:  :black
      }
    }
  end

  def ref
    list_colours[:ref]
  end

  def title
    list_colours[:title]
  end

end
