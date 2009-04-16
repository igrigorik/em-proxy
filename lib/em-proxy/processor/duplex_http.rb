module EventMachine
  module Proxy
    module PostProcessor

      class DuplexHttp
        def initialize(r, b, i)
          @r, @b, @i = r, b, i
        end

        def process
          time = process_time
          body = process_body

          puts [time, body].compact.join("\n")
        end

        protected

        def process_time
          delta = @r.time - @b.time
          str  = delta > 0 ? green("%.4fs" % delta) : red("%.4fs" % delta)
          str += " : Responder: %.4fs" % @r.time
          str += " : Benchmark: %.4fs" % @b.time

          str
        end

        def process_body
          i_head, i_body = @i.data.split("\r\n\r\n") rescue ["",""]
          r_head, r_body = @r.data.split("\r\n\r\n") rescue ["",""]
          b_head, b_body = @b.data.split("\r\n\r\n") rescue ["",""]

          unless r_body == b_body
            str  = highlight("--REQUEST HEAD--") + "\n#{i_head}\n\n"
            str += highlight("--REQUEST BODY--") + "\n#{i_body}\n\n" if i_body

            str += highlight("--RESPONDER HEAD--") + "\n#{r_head}\n\n"
            str += highlight("--RESPONDER BODY--") + "\n#{r_body}\n\n" if r_body

            str += highlight("--BENCHMARK HEAD--") + "\n#{b_head}\n\n"
            str += highlight("--BENCHMARK BODY--") + "\n#{b_body}\n\n" if b_body
            str
          end
        end

        # ANSII colors
        def red(s); colorize(s, "\e[1m\e[31m"); end
        def green(s); colorize(s, "\e[1m\e[32m"); end
        def dark_green(s); colorize(s, "\e[32m"); end
        def yellow(s); colorize(s, "\e[1m\e[33m"); end
        def blue(s); colorize(s, "\e[1m\e[34m"); end
        def dark_blue(s); colorize(s, "\e[34m"); end
        def highlight(s); colorize(s, "\e[7m"); end
        def bold(s); colorize(s, "\e[5m"); end
        def colorize(text, color_code)  "#{color_code}#{text}\e[0m" end
      end

    end
  end
end