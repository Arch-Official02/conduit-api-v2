var http = require('http'),
    path = require('path'),
    methods = require('methods'),
    express = require('express'),
    bodyParser = require('body-parser'),
    session = require('express-session'),
    cors = require('cors'),
    passport = require('passport'),
    errorhandler = require('errorhandler'),
    mongoose = require('mongoose');

var client = require('prom-client');
var collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ timeout: 5000 });
var httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_ms',
  help: 'Duration of HTTP requests in ms',
  labelNames: ['method', 'route', 'status'],
  buckets: [5, 10, 25, 50, 100, 250, 500, 1000]
});

var isProduction = process.env.NODE_ENV === 'production';

var app = express();

app.use(cors());

app.use(function(req, res, next) {
  var start = Date.now();
  res.on('finish', function() {
    var duration = Date.now() - start;
    httpRequestDuration
      .labels(req.method, req.path, res.statusCode)
      .observe(duration);
  });
  next();
});

app.use(require('morgan')('dev'));
app.use(bodyParser.urlencoded({ extended: false }));
app.use(bodyParser.json());
app.use(require('method-override')());
app.use(express.static(__dirname + '/public'));
app.use(session({ secret: 'conduit', cookie: { maxAge: 60000 }, resave: false, saveUninitialized: false }));

if (!isProduction) {
  app.use(errorhandler());
}

if (isProduction) {
  mongoose.connect(process.env.MONGODB_URI);
} else {
  mongoose.connect('mongodb://localhost/conduit', {});
  mongoose.set('debug', true);
  mongoose.set('usePushEach', true);
}

require('./models/User');
require('./models/Article');
require('./models/Comment');
require('./config/passport');

app.use(require('./routes'));

app.get('/metrics', function(req, res) {
  res.set('Content-Type', client.register.contentType);
  client.register.metrics().then(function(metrics) {
    res.end(metrics);
  });
});

app.use(function(req, res, next) {
  var err = new Error('Not Found');
  err.status = 404;
  next(err);
});

if (!isProduction) {
  app.use(function(err, req, res, next) {
    console.log(err.stack);
    res.status(err.status || 500);
    res.json({'errors': {
      message: err.message,
      error: err
    }});
  });
}

app.use(function(err, req, res, next) {
  res.status(err.status || 500);
  res.json({'errors': {
    message: err.message,
    error: {}
  }});
});

var server = app.listen(process.env.PORT || 3000, function() {
  console.log('Listening on port ' + server.address().port);
});

module.exports = server;

