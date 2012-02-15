require File.dirname(__FILE__)+"/tests_init"

require 'test/unit'
require 'triangle_mm'

require 'xml/xxpath_methods'

class MultipleMappingsTest < Test::Unit::TestCase
  def setup
    # need to undo mapping class definitions that may have been
    # established by other tests (and outlive those tests)

    # this requires some ugly hackery with internal variables
    XML::Mapping.module_eval <<-EOS
      Classes_by_rootelt_names.clear
    EOS
    Object.send(:remove_const, "Triangle")
    unless ($".delete "triangle_mm.rb")
      $".delete_if{|name| name =~ %r!test/triangle_mm.rb$!}
    end
    $:.unshift File.dirname(__FILE__)  # test/unit may have undone this (see test/unit/collector/dir.rb)
    require 'triangle_mm'
  end

  def test_read
    t1=Triangle.load_from_file File.dirname(__FILE__) + "/fixtures/triangle_m1.xml", :mapping=>:m1
    assert_raises(XML::MappingError) do
      Triangle.load_from_file File.dirname(__FILE__) + "/fixtures/triangle_m1.xml", :mapping=>:m2
    end
    t2=Triangle.load_from_file File.dirname(__FILE__) + "/fixtures/triangle_m2.xml", :mapping=>:m2

    t=Triangle.new('tri1','green',
                   Point.new(3,0),Point.new(2,4),Point.new(0,1))

    assert_equal t, t1
    assert_equal t, t2
    assert_equal t1, t2
    assert_equal "default description", t2.descr
    assert_nil t1.descr
    assert_not_equal Triangle.allocate, t

    # loading with default mapping should raise an exception because
    # the default mapping was never used yet
    assert_raises(XML::MappingError) do
      Triangle.load_from_file(File.dirname(__FILE__) + "/fixtures/triangle_m1.xml")
    end
    assert_raises(XML::MappingError) do
      Triangle.load_from_file(File.dirname(__FILE__) + "/fixtures/triangle_m2.xml")
    end

    # after using it once, we get empty objects
    Triangle.class_eval "use_mapping :_default"
    assert_equal Triangle.allocate,
                 Triangle.load_from_file(File.dirname(__FILE__) + "/fixtures/triangle_m1.xml")
    assert_equal Triangle.allocate,
                 Triangle.load_from_file(File.dirname(__FILE__) + "/fixtures/triangle_m2.xml")
  end


  def test_read_polymorphic
    t1=XML::Mapping.load_object_from_file File.dirname(__FILE__) + "/fixtures/triangle_m1.xml", :mapping=>:m1
    t2=XML::Mapping.load_object_from_file File.dirname(__FILE__) + "/fixtures/triangle_m2.xml", :mapping=>:m2
    t=Triangle.new('tri1','green',
                   Point.new(3,0),Point.new(2,4),Point.new(0,1))

    assert_equal t, t1
    assert_equal t, t2
    assert_equal t1, t2
  end


  def test_write
    t1=XML::Mapping.load_object_from_file File.dirname(__FILE__) + "/fixtures/triangle_m1.xml", :mapping=>:m1
    m1xml = t1.save_to_xml :mapping=>:m1
    m2xml = t1.save_to_xml :mapping=>:m2

    assert_equal t1.name, m1xml.first_xpath('@name').text
    assert_equal t1.name, m2xml.first_xpath('name').text
    assert_equal t1.p2, Point.load_from_xml(m1xml.first_xpath('pt2'), :mapping=>:m1)
    assert_equal t1.p2, Point.load_from_xml(m2xml.first_xpath('points/point[2]'), :mapping=>:m1)
  end


  def test_root_element
    t1=XML::Mapping.load_object_from_file File.dirname(__FILE__) + "/fixtures/triangle_m1.xml", :mapping=>:m1
    m1xml = t1.save_to_xml :mapping=>:m1
    m2xml = t1.save_to_xml :mapping=>:m2

    assert_equal "triangle", Triangle.root_element_name(:mapping=>:m1)
    assert_equal "triangle", Triangle.root_element_name(:mapping=>:m2)
    assert_equal Triangle, XML::Mapping.class_for_root_elt_name("triangle",:mapping=>:m1)
    assert_equal Triangle, XML::Mapping.class_for_root_elt_name("triangle",:mapping=>:m2)
    assert_equal "triangle", t1.save_to_xml(:mapping=>:m1).name
    assert_equal "triangle", t1.save_to_xml(:mapping=>:m2).name

    Triangle.class_eval <<-EOS
      use_mapping :m1
      root_element_name 'foobar'
    EOS

    assert_equal "foobar", Triangle.root_element_name(:mapping=>:m1)
    assert_equal "triangle", Triangle.root_element_name(:mapping=>:m2)
    assert_nil XML::Mapping.class_for_root_elt_name("triangle",:mapping=>:m1)
    assert_equal Triangle, XML::Mapping.class_for_root_elt_name("foobar",:mapping=>:m1)
    assert_equal Triangle, XML::Mapping.class_for_root_elt_name("triangle",:mapping=>:m2)
    assert_equal "foobar", t1.save_to_xml(:mapping=>:m1).name
    assert_equal "triangle", t1.save_to_xml(:mapping=>:m2).name
    assert_equal [Triangle,:m1], XML::Mapping.class_and_mapping_for_root_elt_name("foobar")
    assert_raises(XML::MappingError) do
      XML::Mapping.load_object_from_xml(m1xml, :mapping=>:m1)
    end
    assert_equal t1, XML::Mapping.load_object_from_xml(m2xml, :mapping=>:m2)
    m1xml.name = "foobar"
    assert_equal t1, XML::Mapping.load_object_from_xml(m1xml, :mapping=>:m1)

    Triangle.class_eval <<-EOS
      use_mapping :m1
      root_element_name 'triangle'
    EOS

    assert_raises(XML::MappingError) do
      XML::Mapping.load_object_from_xml(m1xml, :mapping=>:m1)
    end
    m1xml.name = "triangle"
    assert_equal t1, XML::Mapping.load_object_from_xml(m1xml, :mapping=>:m1)
  end


  def test_node_initialization
  end


  def test_misc
    m1nodes = Triangle.xml_mapping_nodes(:mapping=>:m1).map{|n|n.class}
    m2nodes = Triangle.xml_mapping_nodes(:mapping=>:m2).map{|n|n.class}
    allnodes = Triangle.xml_mapping_nodes.map{|n|n.class}

    t=XML::Mapping::TextNode
    o=XML::Mapping::ObjectNode
    assert_equal [t,o,o,t,o], m1nodes
    assert_equal [o,t,t,o,o,t], m2nodes
    begin
      assert_equal m1nodes+m2nodes, allnodes
    rescue Test::Unit::AssertionFailedError
      assert_equal m2nodes+m1nodes, allnodes
    end

    allm1nodes = Triangle.all_xml_mapping_nodes(:mapping=>:m1).map{|n|n.class}
    allm2nodes = Triangle.all_xml_mapping_nodes(:mapping=>:m2).map{|n|n.class}
    allallnodes = Triangle.all_xml_mapping_nodes.map{|n|n.class}

    assert_equal allm1nodes, m1nodes
    assert_equal allm2nodes, m2nodes
    assert_equal allnodes, allallnodes
  end

end
