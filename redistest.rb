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
end

fail "No available redis servers!" if redis_hosts.empty?
# Find master/slave
redis_masters = Array.new()
redis_slaves = Array.new()
redis_hosts.each { |redis_server|
    if redis_server.is_master?
        redis_masters << redis_server
    elsif redis_server.is_slave?
        redis_slaves << redis_server
    else
        fail "Unknown Redis role: #{redis_server.info["role"]}"
    end
}

if redis_masters.length > 1
    rms = Array.new
    redis_masters.each do |rm|
        rms << rm.inspect.to_s
    end
    fail "More than one master: "+rms.join(",")
end
fail "No Master!" if redis_masters.length < 1
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
    unless redis_server[keyname] == keyname
        fail "Redis server #{redis_server.inspect} failed replication"
    end
end
redis_master.del(keyname)