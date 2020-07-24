#!/usr/bin/env bash

mix deps.get

mix ecto.create
mix ecto.setup

mix test

cd assets/ && yarn install && cd -

iex -S mix phx.server
