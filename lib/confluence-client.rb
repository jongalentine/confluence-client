require 'xmlrpc/client'

module Confluence # :nodoc:
  # = Confluence::Client - Ruby client for the Confluence XML::RPC API.
  # 
  # == Usage
  #
  #   Confluence::Client.new(url) do |confluence|
  #     
  #     if confluence.login(user, pass)
  #       
  #       # Was last API call successful?
  #       confluence.ok?
  #
  #       # Print error message if error on last API call.
  #       puts confluence.error if confluence.error?
  #       
  #       ##########
  #       # Spaces #
  #       ##########
  #       space = confluence.get_space('foo')
  #       if space
  #         puts "found space: #{space.inspect}"
  #       else
  #         space = confluence.add_space( 'foo', 'space name', 'space description' )
  #         if space
  #           puts "created space: #{space.inspect}"
  #         else
  #           puts "unable to create space: #{c.error}"
  #         end
  #       end
  #       
  #       if confluence.remove_space('foo')
  #         puts 'removed space'
  #       else
  #         puts "unable to remove space: #{c.error}"
  #       end
  #       
  #       #########
  #       # Users #
  #       #########
  #       user = confluence.get_user('stan')
  #       if user
  #         puts "found user: #{user.inspect}"
  #       else
  #         user = confluence.add_user( 'stan', 'stan has a name', 'stan@example.com' )       
  #       end
  #       
  #       if confluence.remove_user('stan')
  #         puts 'removed user'
  #       else
  #         puts "unable to remove user: #{c.error}"
  #       end
  #       
  #       #########
  #       # Users #
  #       #########
  #       group = confluence.get_group('some:group')
  #       if group
  #         puts "found group: #{group.inspect}"
  #       else
  #         group = confluence.add_group('some:group')
  #       end
  #
  #       if confluence.remove_group('some:group')
  #         puts 'removed group'
  #       else
  #         puts "unable to remove group: #{c.error}"
  #       end
  #       
  #       confluence.logout
  #     end
  #
  #   end 
  class Client

    # Error message from last request (if any).
    attr_reader :error
    # Security token.
    attr_reader :token

    # Create new Confluence client.
    #
    # Params:
    # +url+:: Base URL for the Confluence XML/RPC API.  'rpc/xmlrpc' appended if not present.
    def initialize(url)
      raise ArgumentError if url.nil? || url.empty?
      url += '/rpc/xmlrpc' unless url =~ /\/rpc\/xmlrpc$/
      @server         = XMLRPC::Client.new2(url)
      @server.timeout = 305                                 # XXX 
      @confluence     = @server.proxy_async('confluence1')  # XXX

      @error          = nil
      @password       = nil
      @token          = nil
      @user           = nil

      yield self if block_given?
    end

    # Create Confluence group.  Returns group hash or nil.
    #
    # Params:
    # +name+:: Group name.
    def add_group(name)
      addGroup(name)
      return { 'name' => name } if ok?
      return nil
    end

    # Create Confluence space.  Return space hash or nil.
    #
    # Params:
    # +key+:: Key for space.
    # +name+:: Name of space.
    # +description+:: Description for space.
    def add_space(key, name, description)
      space = addSpace( { 'key' => key, 'name' => name, 'description' => description } )
      return space if ok?
      nil 
    end

    # Create Confluence user.  Return user hash or nil.
    #
    # Params:
    # +login+:: User login.
    # +name+:: User name.
    # +email+:: User email.
    # +password+:: User password. Defaults to +Time.now.to_i.to_s+.
    def add_user(login, name, email, password = nil )
      addUser( { 'email' => email, 'fullname' => name, 'name' => login }, password || Time.now.to_i.to_s )
      return get_user(login) if ok?
      nil
    end

    # Was there an error on the last request?
    def error?
      !ok?
    end

    # Return Confluence group hash or nil.
    #
    # Params:
    # +name+:: Group name.
    def get_group(name)
      groups = getGroups
      if ok?
        return { 'name' => name } if groups.include?(name)
        @error = 'group not found'
      end
      nil
    end

    # Return Confluence space hash or nil.
    #
    # Params:
    # +key+:: Fetch this space.
    def get_space(key)
      space = getSpace(key)
      return space if ok?
      nil
    end

    # Return Confluence user hash or nil.
    #
    # Params:
    # +login+:: Fetch this user.
    def get_user(login)
      user = getUser(login)
      return user if ok?
      nil
    end

    # Login to the Confluence XML/RPC API.
    def login(user, password)
      raise ArgumentError if user.nil? || password.nil?
      @user, @password = user, password
      begin
        @token  = @confluence.login(@user, @password)
        @error  = nil
      rescue XMLRPC::FaultException => e
        @error = tidy_exception( e.faultString )
      rescue => e
        @error = tidy_exception( e.message )
      end
      return ok?
    end

    def method_missing(method_name, *args)
      unless @token
        @error = "not authenticated"
        return false
      end
      begin
        @error = nil
        return @confluence.send( method_name, *( [@token] + args ) )  
      rescue XMLRPC::FaultException => e
        @error = tidy_exception( e.faultString )
      rescue Exception => e
        @error = tidy_exception( e.message )
      end
      return ok?
    end

    # Was the last request successful?
    def ok?
      @error.nil?
    end

    # Remove Confluence group.  Returns boolean.
    #
    # Params:
    # +name+:: Remove group with this name.
    # +default_group+:: If specified, members of +name+ will be added to this group. Defaults to +''+.
    def remove_group(name, default_group='')
      return removeGroup( name, default_group )
    end

    # Remove Confluence space.  Returns boolean.
    #
    # Params:
    # +key+:: Confluence key for space to remove.
    def remove_space(key)
      return removeSpace(key)
    end

    # Remove Confluence user.  Returns boolean.
    #
    # Params:
    # +login+:: Remove this user.
    def remove_user(login)
      return removeUser(login)
    end

    # Make the Confluence exceptions more readable.
    #
    # Params:
    # +txt+:: Exception text to clean up.
    def tidy_exception(txt)
      txt.gsub!( /^java.lang.Exception: com.atlassian.confluence.rpc.RemoteException:\s+/, '' )
    end

  end # class Client
end # module Confluence

