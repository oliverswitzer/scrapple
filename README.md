# Phoenix Heroku Template

### ♨️  This is a boilerplate template that can be used to deploy a LiveView Phoenix app to Heroku within seconds.

This boilerplate template uses:

* Phoenix 1.6.3
* elixir 1.12.3-otp-24
* erlang 24.1
* LiveView
* esbuild
* Ecto / Postgres 

# 🛠  Customize + Deploy

Just clone the repo, run `./setup.sh` and follow the prompts to rename this template app and automatically deploy to Heroku! (This approach was somewhat inspired by [AlgoVPN](https://github.com/trailofbits/algo)'s simple setup wizard script)

If you'd prefer to do the rename and Heroku deploy manually, feel free to follow along
[here](#manual-rename-and-deploy)

# 🔎 Other considerations

### E-Z CI / CD

You can optionally choose to enable Github Actions for Continuous Deployment

This repository has already defined a very simple Github action workflow that
deploys commits to main to Heroku in `.github/workflows/main.yml`

To enable this, simply edit `.github/workflows/main.yml`, add your email address, and change `replace_me` to your apps name. Finally, set `HEROKU_API_KEY` in your Github repository secrets. If you don't wish to use it, simply remove the file.

### NO DB

If you'd prefer not to use a database, it is relatively easy to disable Ecto; just comment out `RenameMe.Repo,` in `lib/rename_me/application.ex` so it doesn't yell at you when starting up the app.

### Keep Your Heroku App Alive

If you hate the long spin up time that Heroku has for its dynos check out this
cool tool to keep your Heroku app alive called [Kaffeine](https://kaffeine.herokuapp.com/). It will allow your dyno's to sleep just enough to not bump into your monthly dyno time allowance for the Heroku free tier.

### Consider leaving the `setup.sh` script around

Even after deploying your initial app from this template and working on it, you may want to leave the setup script around. If you ever come back to the project that you end up building with this to borrow patterns or entire swathes of code, you'd just need to fork, clone and run the setup script again with the name for you new app. It's like a "fork" that actually only takes a few minutes to have deployed. 

# Local Development

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

# Manual Rename and Deploy

So you decided to take the long route eh? Well, here's what you'll need...

### Rename

Globally replace the `RenameMe` / `rename_me` placeholder in the app with your desired app name

1. I use this the Far.vim [vim tool](https://github.com/brooth/far.vim) to do this.

`:Far RenameMe YourElixirModuleName **/*`

`:Fardo`

`:Far rename_me your_elixir_module_name **/*`

`:Fardo`

If you don't use Vim or prefer not to to use that plugin, you can either use an
editor of your choice or you can use the `find` command with `sed`:

`find . -type f -name '*' -exec sed -i '' s/RenameMe/YourElixirModuleName/g {} +`

`find . -type f -name '*' -exec sed -i '' s/rename_me/your_elixir_module_name/g {} +`

2. Next, rename all files. I use a tool called `rename` with `find` to do this:

`$ brew install rename`

`$ find . -execdir rename -f 's/rename_me/your_elixir_module_name/' '{}' \+ &> /dev/null`

3. Run the app!

` mix deps.get && mix phx.server`

### 🐿 Manual Deployment

Minor changes have been made to `config/runtime.exs` to allow deployments to Heroku.
All you need to do is install the necessary buildpacks and set appropriate environment variables.

1. Create heroku app

`heroku create <your-app-name>`

2. Install buildpacks

`heroku buildpacks:add hashnuke/elixir`

By default, Phoenix uses esbuild and manages all assets for you. However, if you are using node and npm, you will need to install the Phoenix Static buildpack to handle them:

`heroku buildpacks:add https://github.com/gjaldon/heroku-buildpack-phoenix-static.git`

3. Add a database

`$ heroku addons:create heroku-postgresql:hobby-dev`

4. Set these env vars:

```
heroku config:set POOL_SIZE=10
heroku config:set SECRET_KEY_BASE=$(mix phx.gen.secret)
heroku config:set PHX_HOST=<your heroku domain>
```

5. `git push heroku main` to deploy!
