//// Basically a scratch pad to test out different functions while developing them

import gleam/io
import gleam/regexp

pub fn main() {
  io.println(schema)
  echo "divider"

  let assert Ok(re) =
    regexp.from_string("(?m)^\\\\restrict.*\n|^\\\\unrestrict.*\n")
  let schema = regexp.replace(re, schema, "")
  io.println(schema)
}

const schema = "
--
-- PostgreSQL database dump
--

\\unrestrict 7lTJpb6vCMHfzDLz3BJKVB6rjF4mzwT5IBWMAelein0ZMf9grENmvSxlDFtL4TW

\\restrict 7lTJpb6vCMHfzDLz3BJKVB6rjF4mzwT5IBWMAelein0ZMf9grENmvSxlDFtL4TW

-- Dumped from database version 17.5 (Debian 17.5-1.pgdg120+1)
-- Dumped by pg_dump version 17.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
"
