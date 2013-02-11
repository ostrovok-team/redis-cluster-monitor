#!/usr/bin/ruby
require 'rubygems'
require 'redis'

class ReplicatedRedis < Redis
    def is_master?
        self.info["role"] == "master"
    end
    def is_slave?
        self.info["role"] == "slave"
    end
    def is_slave_of?(master)
        raise ArgumentError unless master.is_a?(self.class)
        unless self.is_slave?
            return false
        end
        self.master == master.inspect
    end
    def master
        return nil unless self.is_slave?
        self.info["master_host"]+":"+self.info["master_port"].to_s
    end
    def inspect
        "#{@client.host}:#{@client.port}"
    end
end

def fail(str)
    print str.chomp + "\n"
    exit 1
end

redis_hosts = Array.new()
redis_masters = Array.new()
redis_slaves = Array.new()
ARGV.each do |arg|
    next unless arg =~ /^"?([0-9.a-z]+)(?:[:]([0-9]+))?"?$/
    host = $1
    port = $2.to_i
    port = 6379 if port == 0
    r = ReplicatedRedis.new({ :host => host,
                              :port => port,
                              :timeout => 0.5})
    begin r.randomkey rescue next end
    redis_hosts << r
    if r.is_master?
        redis_masters << r
    elsif r.is_slave?
        redis_slaves << r
    else
        fail "Unknown Redis role: #{r.info["role"]}"
    end
end

fail "No available redis servers!" if redis_hosts.empty?

fail "More than one master: "+redis_masters.map{|r| r.inspect.to_s }.join(",") if redis_masters.length > 1
fail "No Master!" if redis_masters.empty?
fail "No Slaves!" if redis_slaves.empty?

redis_master = redis_masters[0]
redis_slaves.each do |redis_slave|
    unless redis_slave.is_slave_of?(redis_master)
        fail "Redis #{redis_slave.inspect} is pointed to wrong master #{redis_slave.master}, should be #{redis_master.inspect}!"
    end
end

keyname = "replicationtestkey"+Time.now.to_i.to_s
redis_master[keyname] = keyname
sleep 0.5
redis_slaves.each do |redis_server|
    fail "Redis server #{redis_server.inspect} failed replication" unless redis_server[keyname] == keyname
end
redis_master.del(keyname)