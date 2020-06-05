postgresql-patroni-setup
========================

# Overview

This repo it helps you quickly spin up a 3-node cluster of PostgreSQL, managed by Patroni using Consul.

# What's in the cluster?

When you start the cluster, you get 2 nodes (pg01 and pg02), each running:

  - PostgreSQL
  - Patroni
  - Consul agent

and a third node (pg03) running:

  - Consul (server)
  - HAProxy
  - pgBouncer

The connection/data path is the following:

1. pgBouncer (where the app will connect)
2. HAProxy
3. PostgreSQL

All packages are from Ubuntu 16.04, except for PostgreSQL itself, which is at version 12.x.

The cluster is configured with a single primary and one asynchronous streaming replica.

# Dependencies
1. [Virtualbox](https://www.virtualbox.org/wiki/Downloads)
2. [Vagrant](http://www.vagrantup.com/downloads.html)
3. `git clone https://github.com/vtomasr5/postgresql-patroni-setup.git`

# Getting started

1.  On 3 separate windows:
2.  `vagrant up pg03 && vagrant ssh pg03 # pg03 contains the consul server and it must start first` 
3.  `vagrant up pg01 && vagrant ssh pg01`
4.  `vagrant up pg02 && vagrant ssh pg02`

# Viewing cluster status

Get patroni information from his members
  - `patronictl -c /etc/patroni/patroni.yml list`

# Connecting to PostgreSQL

You should use the pgBouncer connection pool
  - 172.28.33.13:6432

But you can also connect via HAproxy using the balancing IP
  - 172.28.33.13:5000 (postgresql)
  - 172.28.33.13:7000 (HAProxy stats)

# TODO

- [X] Add pgBouncer support
- [X] Test on a Windows host (tested on Linux and macOS hosts)
- [ ] Improve documentation

# I have a question!

We're happy to receive questions as issues on this repo, so don't be shy!

It's hard to know exactly what documentation/guidance is useful to people, so we'll use the questions we answer to improve this README and link out to more places you can read up on the technologies we're using.

# Further reading

* [PostgreSQL and Patroni cluster](https://www.linode.com/docs/databases/postgresql/create-a-highly-available-postgresql-cluster-using-patroni-and-haproxy/#before-you-begin)

# References
* [PostgreSQL](https://www.postgresql.org)
* [Patroni](https://patroni.readthedocs.io/en/latest/)
* [HAProxy](https://www.haproxy.org/)
* [Vagrant](http://vagrantup.com)
* [VirtualBox](http://www.virtualbox.org)
