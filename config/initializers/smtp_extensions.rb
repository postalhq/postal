class Net::SMTP::Response

  def message
    @string
  end

end

class Net::SMTP

  attr_accessor :source_address

  def secure_socket?
    @socket.io.is_a?(OpenSSL::SSL::SSLSocket)
  end

  #
  # We had an issue where a message was sent to a server and was greylisted. It returned
  # a Net::SMTPUnknownError error. We then tried to send another message on the same
  # connection after running `rset` the next message didn't raise any exceptions because
  # net/smtp returns a '200 dummy reply code' and doesn't raise any exceptions.
  #
  def rset
    @error_occurred = false
    getok("RSET")
  end

  def rset_errors
    @error_occurred = false
  end

  private

  def tcp_socket(address, port)
    TCPSocket.open(address, port, source_address)
  end

end
