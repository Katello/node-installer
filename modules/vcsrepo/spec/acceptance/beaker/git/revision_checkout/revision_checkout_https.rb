test_name 'C3456 - checkout a revision (https protocol)'

# Globals
repo_name = 'testrepo_revision_checkout'

hosts.each do |host|
  ruby = (host.is_pe? && '/opt/puppet/bin/ruby') || 'ruby'
  tmpdir = host.tmpdir('vcsrepo')
  step 'setup - create repo' do
    git_pkg = 'git'
    if host['platform'] =~ /ubuntu-10/
      git_pkg = 'git-core'
    end
    install_package(host, git_pkg)
    my_root = File.expand_path(File.join(File.dirname(__FILE__), '../../../..'))
    scp_to(host, "#{my_root}/acceptance/files/create_git_repo.sh", tmpdir)
    on(host, "cd #{tmpdir} && ./create_git_repo.sh")
  end
  step 'setup - start https server' do
    https_daemon =<<-EOF
    require 'webrick'
    require 'webrick/https'
    server = WEBrick::HTTPServer.new(
    :Port               => 8443,
    :DocumentRoot       => "#{tmpdir}",
    :SSLEnable          => true,
    :SSLVerifyClient    => OpenSSL::SSL::VERIFY_NONE,
    :SSLCertificate     => OpenSSL::X509::Certificate.new(  File.open("#{tmpdir}/server.crt").read),
    :SSLPrivateKey      => OpenSSL::PKey::RSA.new(          File.open("#{tmpdir}/server.key").read),
    :SSLCertName        => [ [ "CN",WEBrick::Utils::getservername ] ])
    WEBrick::Daemon.start
    server.start
    EOF
    create_remote_file(host, '/tmp/https_daemon.rb', https_daemon)
    #on(host, "#{ruby} /tmp/https_daemon.rb")
  end

  teardown do
    on(host, "rm -fr #{tmpdir}")
    on(host, "ps ax | grep '#{ruby} /tmp/https_daemon.rb' | grep -v grep | awk '{print \"kill -9 \" $1}' | sh ; sleep 1")
  end

  step 'get revision sha from repo' do
    on(host, "git clone https://github.com/johnduarte/testrepo.git #{tmpdir}/foo")
    on(host, "git --git-dir=#{tmpdir}/foo/.git rev-list HEAD | tail -1") do |res|
      @sha = res.stdout.chomp
    end
  end

  step 'checkout a revision with puppet' do
    pp = <<-EOS
    vcsrepo { "#{tmpdir}/#{repo_name}":
      ensure => present,
      source => "https://github.com/johnduarte/testrepo.git",
      provider => git,
      revision => '#{@sha}',
    }
    EOS

    apply_manifest_on(host, pp, :catch_failures => true)
    apply_manifest_on(host, pp, :catch_changes  => true)
  end

  step "verify checkout is set to revision #{@sha}" do
    on(host, "ls #{tmpdir}/#{repo_name}/.git/") do |res|
      fail_test('checkout not found') unless res.stdout.include? "HEAD"
    end

    on(host, "cat #{tmpdir}/#{repo_name}/.git/HEAD") do |res|
      fail_test('revision not found') unless res.stdout.include? "#{@sha}"
    end
  end

end
