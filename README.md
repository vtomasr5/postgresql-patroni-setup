postgresql-patroni-setup
========================

# Overview

This repo it helps you quickly spin up a 2-node cluster of PostgreSQL, managed by Patroni using Consul.

# What's in the cluster?

When you start the cluster, you get 2 nodes, each running:

  - PostgreSQL
  - Patroni

and the pg01 will run also:

  - Consul (server)
  - HAProxy

All packages are from Ubuntu 16.04, except for PostgreSQL itself, which is at version 9.6.

The cluster is configured with a single primary and one asynchronous replica.

# Dependencies
1. [Virtualbox](https://www.virtualbox.org/wiki/Downloads)
2. [Vagrant](http://www.vagrantup.com/downloads.html)
3. `git clone https://github.com/vtomasr5/postgresql-patroni-setup.git`

# Getting started

1.  On 2 separate windows:
2.  `vagrant up pg01 && vagrant ssh pg01`
4.  `vagrant up pg02 && vagrant ssh pg02`

# Viewing cluster status

Get patroni information from his members
  - patronictl -c /etc/patroni/patroni.yml list

# Connecting to PostgreSQL

You can connect via HAproxy using the balancing IP
  - 172.28.33.11:5000 (postgresql)
  - 172.28.33.11:7000 (HAProxy stats)

# TODO

- [ ] Add pgBouncer support
- [ ] Test on a Windows host (tested on Linux and macOS hosts)
- [ ] Add repmgr support
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
