
module XML

  class XPathError < RuntimeError
  end

  # incredibly incomplete. Only implements what I need right now.
  class XPath
    def initialize(xpathstr)
      xpathstr=xpathstr[1..-1] if xpathstr[0]==?/

      # create creators
      @creator_procs = []

      # create readers
      @reader_proc = proc {|nodes| nodes}
      xpathstr.split('/').reverse.each do |part|
        p_prev=@reader_proc
        @reader_proc =
          case part
          when /^(.*?)\[@(.*?)='(.*?)'\]$/
            name,attr_name,attr_value = [$1,$2,$3]
            proc {|nodes|
              next_nodes = Accessors.subnodes_by_name_and_attr(nodes,
                                                               name,attr_name,attr_value)
              if (next_nodes == [])
                throw :not_found, [nodes,"TODO"]
              else
                p_prev.call(next_nodes)
              end
            }
          when /^(.*?)\[(.*?)\]$/
            name,index = [$1,$2.to_i]
            proc {|nodes|
              next_nodes = Accessors.subnodes_by_name_and_index(nodes,
                                                                name,index)
              if (next_nodes == [])
                throw :not_found, [nodes,"TODO"]
              else
                p_prev.call(next_nodes)
              end
            }
          when '*'
            proc {|nodes|
              next_nodes = Accessors.subnodes_by_all(nodes)
              if (next_nodes == [])
                throw :not_found, [nodes,"TODO"]
              else
                p_prev.call(next_nodes)
              end
            }
          else
            proc {|nodes|
              next_nodes = Accessors.subnodes_by_name(nodes,part)
              if (next_nodes == [])
                throw :not_found, [nodes,"TODO"]
              else
                p_prev.call(next_nodes)
              end
            }
          end
      end
    end


    def each(node,create=false,allow_nil=false,&block)
      all(node,create,allow_nil).each(&block)
    end

    def first(node,create=false,allow_nil=false)
      a=all(node,create)
      if a.empty?
        if allow_nil
          nil
        else
          raise XPathError, "no such path: ..."
        end
      else
        a[0]
      end
    end

    def all(node,create=false)
      last_nodes,remaining_path = catch(:not_found) do
        return @reader_proc.call([node])
      end
      if create
        create(last_nodes[0],remaining_path)
      else
        []
      end
    end


    module Accessors

      # read accessors

      for things in %w{name name_and_attr name_and_index all} do
        self.module_eval <<-EOS
          def self.subnodes_by_#{things}(nodes, *args)
            nodes.map{|node| subnodes_by_#{things}_singlesrc(node,*args)}.flatten
          end
        EOS
      end

      def self.subnodes_by_name_singlesrc(node,name)
        node.elements.select{|elt| elt.name==name}
      end

      def self.subnodes_by_name_and_attr_singlesrc(node,name,attr_name,attr_value)
        node.elements.select{|elt| elt.name==name and elt.attributes[attr_name]==attr_value}
      end

      def self.subnodes_by_name_and_index_singlesrc(node,name,index)
        subnodes_by_name_singlesrc(node,name)[index-1]
      end

      def self.subnodes_by_all_singlesrc(node)
        node.elements.to_a
      end


      # write accessors
      #  precondition: we know that a node with exactly the requested attributes
      #                doesn't exist yet (else we wouldn't have been called)

      def self.create_subnode_by_name(node,name)
        node.elements.add name
      end

      def self.create_subnode_by_name_and_attr(node,name,attr_name,attr_value)
        newnode = subnodes_by_name_singlesrc(node,name)[0] || node.elements.add(name)
        newnode.attributes[attr_name]=attr_value
        newnode
      end

      def self.create_subnode_by_name_and_index(node,name,index)
        name_matches = subnodes_by_name_singlesrc(node,name)
        newnode = name_matches[0]
        (index-name_matches.size).times do
          newnode = node.elements.add name
        end
        newnode
      end

      def self.create_subnode_by_all(node)
        # TODO: better strategy here?
        raise XPathError, "don't know how to create '*'" if node.elements.empty?
        node.elements[1]
      end
    end
  end

end
