require File.expand_path('../../katello_ssl_tool', __FILE__)

Puppet::Type.type(:pubkey).provide(:katello_ssl_tool, :parent => Puppet::Provider::KatelloSslTool::CertFile) do

  protected

  def source_path
    cert_details[:pubkey]
  end

end
