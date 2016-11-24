require 'simplecov'
$VERBOSE = nil #FIXME
#SimpleCov.start

require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/totd/page_list'

class TestPageList < MiniTest::Test

  ROOT = File.expand_path File.dirname(__FILE__) + '/../'

  def page
    {
      refs: [1, 2, 3, 4],
      titles: ['title one', 'title two', 'title three', 'title four'],
      locals: [true, false, true, false],
      selected: 2,
      active: 3,
      size: 4
    }
  end

  def setup
    @pl = PageList.new
    @page = page
  end

  def teardown
    @pl = nil
  end

  def test_true
    assert true
  end

  def test_is_a_PageList_object
    assert_equal @pl.class, PageList
  end

  def test_has_method_draw
    @pl.respond_to? :draw
  end

  def test_accepts_a_page_as_argument
    assert @pl.draw @page
  end

  def test_responds_to_ref
    assert @pl.respond_to? :ref
  end

  def test_responds_to_list_colours
    assert @pl.respond_to? :list_colours
  end

  def test_responds_to_title
    assert @pl.respond_to? :title
  end

  def test_ref_is_equal_to_list_colours_ref_key
    @obj = Object.new
    @obj.extend Colour
    assert_equal @pl.ref, @obj.list_colours[:ref]
  end

  def test_title_is_equal_to_list_colours_title_key
    assert_equal extend(Colour).title[:default], extend(Colour).list_colours[:title][:default]
    assert_equal :green, extend(Colour).title[:selected]
  end

  def test_draw_returns_page_for_rendering
    assert_equal %Q{\e[0;32;49m1\e[0m \e[0;30;49mtitle one\e[0m\n\r\e[0;30;49m2\e[0m \e[0;30;49mtitle two\e[0m\n\r\e[0;32;49m3\e[0m \e[0;32;49mtitle three\e[0m\n\r\e[0;34;49m4\e[0m \e[0;34;49mtitle four\e[0m\n\r}, @pl.draw(@page)
  end
end
