# Crantastic

The project is described [here](http://dev.crantastic.org/about). Some other
links of interests are:

- [Crantastic](http://crantastic.org/)
- [Development blog](http://blog.crantastic.org/)
- [User Voice](http://crantastic.uservoice.com/)

The rest of this document contains various pieces of information relevant for
developers/contributors.

## Coding conventions

The [YARD](http://github.com/lsegal/yard/tree/master) meta-tag formatting format
is usued for documentation, whenever it feels necessary.

## Development

Copy `config/database.sample.yml` to `config/database.yml`. It defaults to
SQLite, so no additional configuration of this file is necessary unless you want
to use PostgreSQL (which the site runs on in production).

Run `rake gems:install` to install gem dependencies for the main site.
Do `RAILS_ENV=test rake gems:install` to install the dependencies for the
testing environment (required for running `rake spec`).

Using `autospec` while doing changes to the source code is highly recommended,
as this is very helpful for catching accidental regressions.

After the first checkout of the code you'll have to do check out the Git
submodules. Simply run `git submodule init; git submodule update`.

Note that you should only add/edit stylesheets in the `app/stylesheets` folder.
`public/stylesheets` should only contain compiled Sass styhesleets.

### Solr

A connection to a Solr server is required for running the site. Note that the
version of `acts_as_solr` that is included in the repository is stripped down,
so it does not include the server part. Setting up a Solr server on your
development machine is simple, though:

* Install the Java runtime environment (not necessary on OSX). On Debian or
  Ubuntu this can be done with: sudo apt-get install sun-java6-jre
* git clone git://github.com/mattmatt/acts_as_solr.git
* cd acts_as_solr/solr && java -jar start.jar

Then you can run `rake solr:reindex` from the folder where you have the
crantastic source code.

### R package

There is a R package for crantastic that lives in its own branch in the Git
repository. Use the following steps to check out the source:

    git fetch origin R-package
    git checkout --track -b R-package origin/R-package

## Working with Heroku

### Setting up the Heroku remote

    git remote add heroku git@heroku.com:crantastic.git

Confirm that it's working by running `heroku info`.

### Pulling the latest database from crantastic.org

    heroku db:pull

This will overwrite `db/development.sqlite3`.

### Pushing your work to Heroku

    git push heroku master

Personally I use an alias so I don't have to type as much:

    alias gph='git push heroku master'

## Updating packages from CRAN

Run `rake crantastic:cron` or `rake crantastic:update_all_packages`.

## License

The crantastic source code is released under the MIT license, consult the
accompanying MIT-LICENSE file for details.
