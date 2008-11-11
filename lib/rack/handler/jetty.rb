require 'java'
%w{jetty-6.1.3 jetty-util-6.1.3 servlet-api-2.5-6.1.3}.each { |l|require File.dirname(__FILE__) + '/../../../ext/' + l+ '.jar' }
require 'stringio'
import org.mortbay.jetty
import org.mortbay.jetty.handler

module Rack
  module Handler
    class Jetty < org.mortbay.jetty.handler.AbstractHandler
      
      def self.run(app, options={})
        include_class org.mortbay.jetty.Server
        server = Server.new(options[:Port]);
        server.setHandler(Rack::Handler::Jetty.new(app));
        server.start();
        server.join()
      end

      def initialize(app)
        include_class javax.servlet.ServletException;
        include_class javax.servlet.http.HttpServletRequest;
        include_class javax.servlet.http.HttpServletResponse;
        @app = app
        super()
      end
      
      def handle(target,  request, response, dispatch)
        env = { }
        request.getHeaderNames.each { |h| env[h.to_s] = request.getHeader(h.to_s) }
        env['HTTP_HOST'] = request.getServerName()
        env['REQUEST_METHOD'] = request.getMethod()
        env['SERVER_PORT'] = request.getServerPort()
        env['QUERY_STRING'] = request.getQueryString()
        env.update Rack::Utils.parse_query(request.getQueryString())
        #env['SCRIPT_NAME'] = env['PATH_INFO'] = request.getPathInfo()
        env['PATH_INFO'] = request.getPathInfo()
        #Find out if body is available for the request. Need to find a better way of doing this.
        if env['Transfer-Encoding'] =~ /chunked/i
          input_stream = request.getInputStream()
        else
          input_stream = StringIO.new("")
          reader = request.getReader
          while(line = reader.readLine); input_stream.write(line) ; end
          input_stream.rewind
        end
          
        env.update({"rack.version" => [0,1],
                     "rack.input" => input_stream,
                     "rack.errors" => STDERR,

                     "rack.multithread" => true,
                     "rack.multiprocess" => false, # ???
                     "rack.run_once" => false,

                     "rack.url_scheme" => "http",
                   })
        env["QUERY_STRING"] ||= ""
        env.delete "PATH_INFO"  if env["PATH_INFO"] == ""
        status, headers, resp = @app.call(env)
        
=begin        env = {}.replace(request.params)
        env.delete "HTTP_CONTENT_TYPE"
        env.delete "HTTP_CONTENT_LENGTH"

        env["SCRIPT_NAME"] = ""  if env["SCRIPT_NAME"] == "/"

=end
        base_request = request
        base_request.setHandled(true);
        response.setStatus(status);
        response.setContentType(headers['Content-Type']);
        response.getWriter().print(resp.body) unless status.to_s =~ /^4/ # need send right text when return error statuses.

      end
    end
  end
end
