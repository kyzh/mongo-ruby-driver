# Copyright (C) 2014-2015 MongoDB, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'socket'
require 'timeout'
require 'mongo/socket/ssl'
require 'mongo/socket/tcp'
require 'mongo/socket/unix'

module Mongo

  # Provides additional data around sockets for the driver's use.
  #
  # @since 2.0.0
  class Socket
    include ::Socket::Constants

    # Error message for SSL related exceptions.
    #
    # @since 2.0.0
    SSL_ERROR = 'SSL handshake failed. MongoDB may not be configured with SSL support.'.freeze

    # Error message for timeouts on socket calls.
    #
    # @since 2.0.0
    TIMEOUT_ERROR = 'Socket request timed out'.freeze

    # The pack directive for timeouts.
    #
    # @since 2.0.0
    TIMEOUT_PACK = 'l_2'.freeze

    # @return [ Integer ] family The type of host family.
    attr_reader :family

    # @return [ Socket ] socket The wrapped socket.
    attr_reader :socket

    # Is the socket connection alive?
    #
    # @example Is the socket alive?
    #   socket.alive?
    #
    # @return [ true, false ] If the socket is alive.
    #
    # @since 2.0.0
    def alive?
      if Kernel::select([ socket ], nil, [ socket ], 0)
        !eof? rescue false
      else
        true
      end
    rescue IOError
      false
    end

    # Close the socket.
    #
    # @example Close the socket.
    #   socket.close
    #
    # @return [ true ] Always true.
    #
    # @since 2.0.0
    def close
      socket.close rescue true
      true
    end

    # Delegates gets to the underlying socket.
    #
    # @example Get the next line.
    #   socket.gets(10)
    #
    # @param [ Array<Object> ] args The arguments to pass through.
    #
    # @return [ Object ] The returned bytes.
    #
    # @since 2.0.0
    def gets(*args)
      handle_errors { socket.gets(*args) }
    end

    # Create the new socket for the provided family - ipv4, piv6, or unix.
    #
    # @example Create a new ipv4 socket.
    #   Socket.new(Socket::PF_INET)
    #
    # @param [ Integer ] family The socket domain.
    #
    # @since 2.0.0
    def initialize(family)
      @family = family
      @socket = ::Socket.new(family, SOCK_STREAM, 0)
      encoded_timeout = [ timeout, 0 ].pack(TIMEOUT_PACK)
      socket.set_encoding(BSON::BINARY)
      socket.setsockopt(SOL_SOCKET, SO_RCVTIMEO, encoded_timeout)
      socket.setsockopt(SOL_SOCKET, SO_SNDTIMEO, encoded_timeout)
    end

    # Will read all data from the socket for the provided number of bytes.
    # If less data is returned than requested, an exception will be raised.
    #
    # @example Read all the requested data from the socket.
    #   socket.read(4096)
    #
    # @param [ Integer ] length The number of bytes to read.
    #
    # @raise [ Mongo::SocketError ] If not all data is returned.
    #
    # @return [ Object ] The data from the socket.
    #
    # @since 2.0.0
    def read(length)
      data = handle_errors{ socket.read(length) } || String.new
      if data.length < length
        data << read(length - data.length)
      end
      data
    end

    # Read a single byte from the socket.
    #
    # @example Read a single byte.
    #   socket.readbyte
    #
    # @return [ Object ] The read byte.
    #
    # @since 2.0.0
    def readbyte
      handle_errors { socket.readbyte }
    end

    # Writes data to the socket instance.
    #
    # @example Write to the socket.
    #   socket.write(data)
    #
    # @param [ Array<Object> ] args The data to be written.
    #
    # @return [ Integer ] The length of bytes written to the socket.
    #
    # @since 2.0.0
    def write(*args)
      handle_errors { socket.write(*args) }
    end

    private

    def handle_errors
      begin
        yield
      rescue Errno::ETIMEDOUT
        raise Mongo::SocketTimeoutError, TIMEOUT_ERROR
      rescue IOError, SystemCallError => e
        raise Mongo::SocketError, e.message
      rescue OpenSSL::SSL::SSLError
        raise Mongo::SocketError, SSL_ERROR
      end
    end
  end
end
