#! /usr/bin/env python
# -*- coding: utf-8 -*-
# vim:fenc=utf-8

# Thanks to https://gist.github.com/cabecada/da8913830960a644755b18a02b65e184

import psycopg2

ISOLEVEL = psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT

import time
import random

user = 'postgres'
password = 'secretpassword'

host = '172.28.33.13'
port = '6432'
database = 'test'
LIMIT_RETRIES = 10

class DB():
    def __init__(self, user, password, host, port, database, reconnect):
        self.user = user
        self.password = password
        self.host = host
        self.port = port
        self.database = database
        self._connection = None
        self._cursor = None
        self.reconnect = reconnect
        self.retry_time = -1
        self.init()

    def connect(self,retry_counter=0):
        if not self._connection:
            try:
                self._connection = psycopg2.connect(user = self.user, password = self.password, host = self.host, port = self.port, database = self.database, connect_timeout=3, )
                retry_counter = 0
                self._connection.autocommit = True
                return self._connection
            except psycopg2.OperationalError as error:
                if not self.reconnect or retry_counter >= LIMIT_RETRIES:
                    raise error
                else:
                    start = time.time()
                    retry_counter += 1
                    print("got error {}. reconnecting {}".format(str(error).strip(), retry_counter))
                    time.sleep(5)
                    self.connect(retry_counter)
                    end = time.time()
                    self.retry_time += end - start
            except (Exception, psycopg2.Error) as error:
                raise error

    def cursor(self):
        if not self._cursor or self._cursor.closed:
            if not self._connection:
                self.connect()
            self._cursor = self._connection.cursor()
            return self._cursor

    def execute(self, query, retry_counter=0):
        try:
            #query = "set statement_timeout=3;" + query
            self._cursor.execute(query)
            retry_counter = 0
        except (psycopg2.DatabaseError, psycopg2.OperationalError) as error:
            if retry_counter >= LIMIT_RETRIES:
                raise error
            else:
                start = time.time()
                retry_counter += 1
                print("got error {}. retrying {}".format(str(error).strip(), retry_counter))
                time.sleep(1)
                self.reset()
                self.execute(query, retry_counter)
                end = time.time()
                self.retry_time += end - start
                if self.retry_time != -1:
                    print("time spent retrying: %0.3fms" % (self.retry_time*1000))
        except (Exception, psycopg2.Error) as error:
            raise error
#        return self._cursor.fetchone()

#    def is_master(self):
#        row = self.execute("select pg_is_in_recovery();")
#        if row and row[0]:
#            return False
#        return True

    def reset(self):
        self.close()
        self.connect()
        self.cursor()

    def close(self):
        if self._connection:
            if self._cursor:
                self._cursor.close()
            self._connection.close()
            print("PostgreSQL connection is closed")
        self._connection = None
        self._cursor = None

    def init(self):
        self.connect()
        self.cursor()

db = DB(user=user, password=password, host=host, port=port, database=database, reconnect=True)
i = 0
while True:
    db.execute("create table if not exists t1 (id integer); ")
    db.execute("insert into t1(id) values(%d)" % random.randint(1, 1000))
    if i % 10000 == 0:
        print(i)
    i = i+1
