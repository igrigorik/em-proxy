require "lib/em-proxy"
require "em-mysql"
require "fiber"

Proxy.start(:host => "0.0.0.0", :port => 3307) do |conn|
  conn.server :mysql, :host => "127.0.0.1", :port => 3306, :relay_server => true

  QUERY_CMD = 3

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

        case query.first
        when "create" then
          # allow schemaless table creation, ex: 'create table posts'
          # by creating a table with a single id for key storage, aka
          # rewrite to: 'create table posts (id varchar(255))'. all
          # future attribute tables will be created on demand at
          # insert time of a new record
          overload = "(id varchar(255), UNIQUE(id));"
          query += [overload]
          overhead += overload.size + 1

          p [:create_new_schema_free_table, query, data]

        when "insert" then
          # overload the INSERT syntax to allow for nested parameters
          # inside the statement. ex:
          #   INSERT INTO posts VALUE("post_id_1", (
          #     ("author", "Ilya Grigorik"),
          #     ("nickname", "igrigorik")
          #   ))
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
          if query[3] =~ /^value\(/
       
            table = query[2]
            key   = query[3].match(/\"(.*?)\"/)[1]
            values = query.last(query.size - 4)

            values.join(" ").squeeze("()").scan(/\(.*?\)/).each do |value|
              value = value.match(/'(.*?)'.*?'(.*?)'/)
              attr_sql = "insert into #{table}_#{value[1]} values('#{key}', '#{value[2]}')"

              q = @mysql.query(attr_sql)
              q.errback  { |res|
                # if the attribute table for this model does not yet exist then create it!
                # - yes, there is a race condition here, add a fiber later
                if res.is_a?(Mysql::Error) and res.message =~ /Table.*doesn\'t exist/

                  table_sql = "create table #{table}_#{value[1]} (id varchar(255), value varchar(255), UNIQUE(id))"
                  tc = @mysql.query(table_sql)
                  tc.callback { @mysql.query(attr_sql) }

                  p [:created_new_attr_table, "#{table}_#{value[1]}"]
                end
              }

              p [:inserted_attr, table, key, value[2]]
            end

            # override the query to insert the key into posts table
            query = query[0,3] + [query[3].chop + ")"]
            overhead = query.join(" ").size + 1

            p [:insert, query]
          end

        when "select" then
          attrs = sql.match(/select(.*?)from/)[1].strip.split(',')
          p [:select, attrs]

          tables = @mysql.query("show tables like 'posts_%'")
          tables.callback {|res| fiber.resume(res.all_hashes.collect(&:values).flatten) }
          tables = Fiber.yield + [table]
          
          p [:select_tables, tables]
#          query = tables

          #  select posts.id as id, posts_author.value as author FROM posts
          #   LEFT OUTER JOIN posts_author ON posts_author.id = posts.id
          #   WHERE posts.id = "ilya";
          # select posts.id as id, posts_author.value as author FROM posts LEFT OUTER JOIN posts_author ON posts_author.id = posts.id WHERE posts.id = "ilya";


        end

        # repack the query data and forward to server
        data = [overhead, chunks, seq].pack("CvC") + [type, query.join(" ")].pack("Ca*")

        p [:final_query, data]
        puts "-" * 100
      end

      conn.relay_to_servers(data)

      :async # we will render results later
    }

    fiber.resume
  end
end

# create table #{table}_#{value[1]} (id varchar(255), value varchar(255), UNIQUE(id))