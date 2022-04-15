# Scrapple

A declarative JSON language for coordinating scheduled web scraping

# Development

Install deps and compile:

`mix deps.get && mix compile`

Install playwright browsers:

`mix playwright.install`

Create database (ensure postgres is running):

`mix ecto.create`


## Running test

`MIX_ENV=test mix ecto.create`

`mix test`
