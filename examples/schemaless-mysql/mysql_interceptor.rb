require "lib/em-proxy"
require "em-mysql"
require "stringio"
require "fiber"

Proxy.start(:host => "0.0.0.0", :port => 3307) do |conn|
  conn.server :mysql, :host => "127.0.0.1", :port => 3306, :relay_server => true

  QUERY_CMD = 3
  MAX_PACKET_LENGTH = 2**24-1

  # open a direct connection to MySQL for the schema-free coordination logic
  @mysql = EventMachine::MySQL.new(:host => 'localhost', :database => 'noschema')

  conn.on_data do |data|
    fiber = Fiber.new {
      p [:original_request, data]

      overhead, chunks, seq = data[0,4].unpack("CvC")
      type, sql = data[4, data.size].unpack("Ca*")

      p [:request, [overhead, chunks, seq], [type, sql]]

      if type == QUERY_CMD
        query = sql.downcase.split
        p [:query, query]

        # TODO: can probably switch to http://github.com/omghax/sql
        #       for AST query parsing & mods.

        case query.first
        when "create" then
          # Allow schemaless table creation, ex: 'create table posts'
          # By creating a table with a single id for key storage, aka
          # rewrite to: 'create table posts (id varchar(255))'. All
          # future attribute tables will be created on demand at
          # insert time of a new record
          overload = "(id varchar(255), UNIQUE(id));"
          query += [overload]
          overhead += overload.size + 1

          p [:create_new_schema_free_table, query, data]

        when "insert" then
          # Overload the INSERT syntax to allow for nested parameters
          # inside the statement. ex:
          #   INSERT INTO posts (id, author, nickname, ...) VALUES (
          #     'ilya', 'Ilya Grigorik', 'igrigorik'
          #   )
          #
          # The following query will be mapped into 3 distinct tables:
          # => 'posts' table will store the key
          # => 'posts_author' will store key, value
          # => 'posts_nickname' will store key, value
          #
          #  or, in SQL..
          #
          # =>  insert into posts values("ilya");
          # =>  create table posts_author (id varchar(40), value varchar(255), UNIQUE(id));
          # =>  insert into posts_author values("ilya", "Ilya Grigorik");
          # =>  ... repeat for every attribute
          #
          # If the table post_value has not been seen before, it will
          # be created on the fly. Hence allowing us to add and remove
          # keys and values at will. :-)
          #
          # P.S. There is probably cleaner syntax for this, but hey...
            
            
          if insert = sql.match(/\((.*?)\).*?\((.*?)\)/)
            data = {}
            table = query[2]
            keys = insert[1].split(',').map!{|s| s.strip}
            values = insert[2].scan(/([^\'|\"]+)/).flatten.reject {|s| s.strip == ','}
            keys.each_with_index {|k,i| data[k] = values[i]}

            data.each do |key, value|
              next if key == 'id'
              attr_sql = "insert into #{table}_#{key} values('#{data['id']}', '#{value}')"

              q = @mysql.query(attr_sql)
              q.errback  { |res|
                # if the attribute table for this model does not yet exist then create it!
                # - yes, there is a race condition here, add fiber logic later
                if res.is_a?(Mysql::Error) and res.message =~ /Table.*doesn\'t exist/

                  table_sql = "create table #{table}_#{key} (id varchar(255), value varchar(255), UNIQUE(id))"
                  tc = @mysql.query(table_sql)
                  tc.callback { @mysql.query(attr_sql) }
                end
              }

              p [:inserted_attr, table, key, value]
            end

            # override the query to insert the key into posts table
            query = query[0,3] + ["VALUES('#{data['id']}')"]
            overhead = query.join(" ").size + 1

            p [:insert, query]
          end

        when "select" then
          # Overload the select call to perform a multi-join in the background
          # and rewrite the attribute names to fool the client into thinking it
          # all came from the same table.
          #
          # To figure out which tables we need to join on, do the simple / dumb
          # approach and issue a 'show tables like key_%' to do 'runtime
          # introspection'. Could easily cache this, but that's for later.
          #
          # Ex, a 'select * from posts' query with one value (author) would be
          # rewritten into the following query:
          #
          #  SELECT posts.id as id, posts_author.value as author FROM posts
          #   LEFT OUTER JOIN posts_author ON posts_author.id = posts.id
          #   WHERE posts.id = "ilya";

          select = sql.match(/select(.*?)from\s([^\s]+)/)
          where  = sql.match(/where\s([^=]+)\s?=\s?'?"?([^\s'"]+)'?"?/)
          attrs, table = select[1].strip.split(','), select[2] if select
          key = where[2] if where

          if select
            p [:select, select, attrs, where]

            tables = @mysql.query("show tables like '#{table}_%'")
            tables.callback { |res|
              fiber.resume(res.all_hashes.collect(&:values).flatten.collect{ |c|
                  c.split('_').last
                })
            }
            tables = Fiber.yield

            p [:select_tables, tables]

            # build the select statements, hide the tables behind each attribute
            join =  "select #{table}.id as id "
            tables.each do |column|
              join += " , #{table}_#{column}.value as #{column} "
            end

            # add the joins to stich it all together
            join += " FROM #{table} "
            tables.each do |column|
              join += " LEFT OUTER JOIN #{table}_#{column} ON #{table}_#{column}.id = #{table}.id "
            end

            join += " WHERE #{table}.id = '#{key}' " if key

            query = [join]
            overhead = join.size + 1

            p [:join_query, join]
          end
        end

        # repack the query data and forward to server
        # - have to split message on packet boundaries

        seq, data = 0, []
        query = StringIO.new([type, query.join(" ")].pack("Ca*"))
        while q = query.read(MAX_PACKET_LENGTH)
          data.push [q.length % 256, q.length / 256, seq].pack("CvC") + q
          seq = (seq + 1) % 256
        end

        p [:final_query, data, chunks, overhead]
        puts "-" * 100
      end

      [data].flatten.each do |chunk|
        conn.relay_to_servers(chunk)
      end

      :async # we will render results later
    }

    fiber.resume
  end
end
