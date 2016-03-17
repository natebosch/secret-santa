# Setting up Apache for routes

```
$ a2enmod rewrite
```

Edit `/etc/apache2/sites-available/<site>.conf` and add:

```
RewriteEngine On
  # If an existing asset or directory is requested go to it as it is
  RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} -f [OR]
  RewriteCond %{DOCUMENT_ROOT}%{REQUEST_URI} -d
  RewriteRule ^ - [L]

  # If the requested resource doesn't exist, use index.html
  RewriteRule ^ /index.html
```

```
$ service apache2 restart
```


