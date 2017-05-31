
module DB
  Config = {
      'development' => {
          'username'   => 'VILEVEN',
          'password' => 'Chelsea11',
          'database' => 'VILEVEN'
      },
      'test'        => { },
      # note that 'production' will be overridden by
      # ENV['DATABASE_URL'] in, e.g. Heroku
      'production'  => { }
  }
end