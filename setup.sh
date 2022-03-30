#!/bin/bash

rename_cwd() {
  cd . || return
  new_dir=${PWD%/*}/$1
  mv -- "$PWD" "$new_dir" &&
    cd -- "$new_dir"
}


if grep -R -l rename lib > /dev/null; then
  echo ""
else
  read -p "You've already renamed this app. Are you sure you want to rename it
  again? Y/n " -n 1 -r

  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Nn]$ ]]; then
    exit 1
  fi
fi

read -p "Need to install tool 'rename' in order to globally rename files in this project. Is that ok? Y/n " -n 1 -r

echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  brew install rename
else
  echo "Aborting"
  exit 1
fi

cat << EOF


What module name would you like to give this app? 

  Example: MyApp would create MyApp and MyAppWeb module prefixes, with a file
    structure like so:

      * lib/my_app/...
      * lib/my_app_web/..
      * test/my_app/...
      * test/my_app_web/...

      Note: it will also be used as the default name for your Heroku app when automatically deploying to Heroku later, ie my-app.herokuapp.com (you can skip this step if you'd like)

EOF

read module_name
export module_name

export snake_name=$(echo $module_name | sed 's/[[:upper:]]/_&/g;s/^_//' | tr '[:upper:]' '[:lower:]')

echo "Renaming all instances of ReplaceMe with $module_name and replace_me with
$snake_name in project..."
LC_ALL=C find lib config test assets priv -type f -name '*' -exec sed -i '' s/RenameMe/$module_name/g {} +
LC_ALL=C find lib config test assets priv -type f -name '*' -exec sed -i '' s/rename_me/$snake_name/g {} +

sed -I '' "s/RenameMe/$module_name/g" mix.exs
sed -I '' "s/rename_me/$snake_name/g" mix.exs


# Rename all folders/files using rename 
find . -execdir rename -f 's/rename_me/\Q$ENV{snake_name}\E/' '{}' \+ &> /dev/null

echo "Heads up! Also renaming the current working directory to $snake_name..."
rename_cwd $snake_name

echo "✅ Done! your app is renamed to $snake_name / $module_name."
echo 
                                                                             
read -p "Do you want to setup Heroku? Y/n " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then 
  echo "First compiling the app to be able run mix phx.gen.secret..."
  mix deps.get && mix compile 


  echo "Creating Heroku app with Postgresql Hobby Dev database..."
  heroku create
  heroku addons:create heroku-postgresql:hobby-dev
  heroku buildpacks:add hashnuke/elixir
  heroku config:set POOL_SIZE=10 SECRET_KEY_BASE=$(mix phx.gen.secret) PHX_HOST=$(heroku domains | awk 'FNR == 2 {print}')
  git push heroku main

  cat << EOF
 ______     __  __     ______     ______     ______     ______     ______    
/\  ___\   /\ \/\ \   /\  ___\   /\  ___\   /\  ___\   /\  ___\   /\  ___\   
\ \___  \  \ \ \_\ \  \ \ \____  \ \ \____  \ \  __\   \ \___  \  \ \___  \  
 \/\_____\  \ \_____\  \ \_____\  \ \_____\  \ \_____\  \/\_____\  \/\_____\ 
  \/_____/   \/_____/   \/_____/   \/_____/   \/_____/   \/_____/   \/_____/ 
EOF
  echo 
  echo "🐿  Reminder don't forget to setup continuous deployment! Open
  .github/workflows/main.yml and plug in your Heroku details to setup
  auto-deploys to Heroku"
  sleep 5
  heroku open
else
  echo "Skipping: deploy to Heroku"
fi

read -p "Do you want to rename the heroku app? Y/n" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
  export renaming_heroku_instance=true
  while $renaming_heroku_instance; do
    echo "What would you like to rename it to? (kebab-case only): "
    read heroku_name
    heroku rename $heroku_name

    if [ $? -eq 0 ]; then
      renaming_heroku_instance=false
      heroku config:set PHX_HOST=$(heroku domains | awk 'FNR == 2 {print}')
    else
      echo "Whoops, try again..."
      echo
    fi
  done
else
  echo "Skipping: compile & run the app"
fi

echo
echo
read -p "Do you want to run the app locally? (ensure that you have postgres running first) Y/n " -n 1 -r

echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  mix ecto.create && mix ecto.migrate && mix phx.server
else
  echo "Skipping: compile & run the app"
fi
