require 'simplecov'
$VERBOSE = nil #FIXME
#SimpleCov.start

require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/totd/colour'

class TestColours < MiniTest::Test

  ROOT = File.expand_path File.dirname(__FILE__) + '/../'

  include Colour

  def setup
    @obj = Object.new
    @obj.extend(Colour)
  end

  def teardown
    @c = nil
  end

  def test_true
    assert true
  end

  def test_colour_is_a_module
    assert_equal Colour.class, Module
  end

  def test_colour_module_has_method_named_list_colours
    assert @obj.respond_to? :list_colours
  end

  def test_list_colours_returns_a_hash
    assert @obj.list_colours.is_a? Hash
  end

  def test_list_colours_has_the_ref_key
    assert @obj.list_colours.has_key? :ref
  end

  def test_list_colours_has_the_title_key
    assert @obj.list_colours.has_key? :ref
  end

  def test_ref_has_act_sel_sub_key
    assert @obj.list_colours[:ref].has_key? :act_sel
  end

  def test_ref_has_selected_sub_key
    assert @obj.list_colours[:title].has_key? :selected
  end

  def test_ref_has_active_sub_key
    assert @obj.list_colours[:ref].has_key? :active
  end

  def test_list_colours_has_locals_sub_key_for_ref
    assert @obj.list_colours[:ref].has_key? :local
  end

  def test_responds_to_ref
    assert @obj.respond_to? :ref
  end

  def test_responds_to_title
    assert @obj.respond_to? :title
  end

  def test_title_is_equal_to_list_colours_title_key
    assert_equal @obj.title, @obj.list_colours[:title]
  end
end
