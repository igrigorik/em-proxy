require "lib/em-proxy"
require "em-mysql"

Proxy.start(:host => "0.0.0.0", :port => 3307) do |conn|
  conn.server :mysql, :host => "127.0.0.1", :port => 3306

  QUERY_CMD = 3

  # open a direct connection to MySQL for the schema-free coordination logic
  @mysql = EventMachine::MySQL.new(:host => 'localhost', :database => 'noschema')

  conn.on_data do |data|
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
        # rewrite to: 'create table posts (id varchar(255))'
        overload = "(id varchar(255), UNIQUE(id));"
        query += [overload]
        overhead += overload.size + 1

        p [:create, query, data]

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
        # If the table post_value has not been seen before, it will
        # be created on the fly. Hence allowing us to add and remove
        # keys and values at will. :-)
        #
        # P.S. There is probably cleaner syntax for this, but hey...
        if query[3] =~ /^value\(/
       
          # INSERT INTO posts VALUE("post_id_1", (('author', 'Ilya Grigorik'),('nickname', 'igrigorik')))

          original_query = query
        
          # insert into posts values("ilya");
          # insert into posts_nickname values("ilya", "igrigorik");
          # create table posts_nickname (id varchar(40), value varchar(255));


          # override the query to insert the key into posts table
          query = query[0,3] + [query[3].chop + ")"]
          overhead = query.join(" ").size + 1

          p [:insert, query]
        end

      when "select" then
        p [:select]
        #        query = conn.query("select 1+1")
        #        query.callback { |res| p res.all_hashes }
        #        query.errback  { |res| p res.all_hashes }
        # select posts.id as id, posts_author.value as author FROM posts
        #   LEFT OUTER JOIN posts_author ON posts_author.id = posts.id
        #   WHERE posts.id = "ilya";
     
      end

      # repack the query data and forward to server
      data = [overhead, chunks, seq].pack("CvC") + [type, query.join(" ")].pack("Ca*")

      p [:final_query, data]
    end

    data
  end

  conn.on_response do |backend, resp|
    p [:response, resp]
    resp
  end
end