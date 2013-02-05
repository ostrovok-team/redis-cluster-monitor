redis-cluster-monitor
=====================

Redis cluster (Master-Slave replication) monitoring utility

This is simple Ruby script for monitoring Redis clusters.
It checks if all Redis servers are listening to the same master, if cluster has one and only one master.

Usage:
redistest.rb <serv1:port1> <serv2:port2> [serv3:port3] [serv4:port4]...
