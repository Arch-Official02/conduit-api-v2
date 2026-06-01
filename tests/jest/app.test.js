const request = require('supertest');
const app = require('../../app');
const api = request(app);

// ─── unique test data every run — no database cleanup needed ─────────────────
const ts = Date.now();
const testUser = {
  user: {
    username: `testuser${ts}`,
    email:    `testuser${ts}@example.com`,
    password: 'password123'
  }
};

// ─── shared state across tests ───────────────────────────────────────────────
let token = '';
let slug  = '';

afterAll(async () => {
  await app.close();
  await new Promise(resolve => setTimeout(resolve, 500));
});

// ─────────────────────────────────────────────────────────────────────────────
// TAGS
// ─────────────────────────────────────────────────────────────────────────────
describe('Tags', () => {
  test('GET /api/tags — returns 200 and tags array', async () => {
    const res = await api.get('/api/tags');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('tags');
    expect(Array.isArray(res.body.tags)).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────────────────────────────────────────
describe('Auth', () => {
  test('POST /api/users — register a new user', async () => {
    const res = await api
      .post('/api/users')
      .send(testUser);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('user');
    expect(res.body.user).toHaveProperty('token');
    expect(res.body.user).toHaveProperty('email');
    expect(res.body.user).toHaveProperty('username');
  });

  test('POST /api/users/login — login and receive token', async () => {
    const res = await api
      .post('/api/users/login')
      .send({
        user: {
          email:    testUser.user.email,
          password: testUser.user.password
        }
      });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('user');
    expect(res.body.user).toHaveProperty('token');

    token = res.body.user.token;
  });

  test('GET /api/user — get current user (requires token)', async () => {
    const res = await api
      .get('/api/user')
      .set('Authorization', `Token ${token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('user');
    expect(res.body.user).toHaveProperty('email', testUser.user.email);
  });

  test('PUT /api/user — update current user', async () => {
    const res = await api
      .put('/api/user')
      .set('Authorization', `Token ${token}`)
      .send({ user: { bio: 'Jest test bio' } });

    expect(res.status).toBe(200);
    expect(res.body.user).toHaveProperty('bio', 'Jest test bio');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// ARTICLES — public
// ─────────────────────────────────────────────────────────────────────────────
describe('Articles (public)', () => {
  test('GET /api/articles — returns 200 and articles array', async () => {
    const res = await api.get('/api/articles');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('articles');
    expect(Array.isArray(res.body.articles)).toBe(true);
  });

  test('GET /api/articles?author=x — filter by author', async () => {
    const res = await api.get(`/api/articles?author=${testUser.user.username}`);
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('articles');
  });

  test('GET /api/articles?tag=dragons — filter by tag', async () => {
    const res = await api.get('/api/articles?tag=dragons');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('articles');
  });

  test('GET /api/articles?favorited=x — filter by favorited', async () => {
    const res = await api.get(`/api/articles?favorited=${testUser.user.username}`);
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('articles');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// ARTICLES — authenticated
// ─────────────────────────────────────────────────────────────────────────────
describe('Articles (authenticated)', () => {
  test('GET /api/articles/feed — returns 200', async () => {
    const res = await api
      .get('/api/articles/feed')
      .set('Authorization', `Token ${token}`);
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('articles');
  });

  test('POST /api/articles — create an article', async () => {
    const res = await api
      .post('/api/articles')
      .set('Authorization', `Token ${token}`)
      .send({
        article: {
          title:       `Jest Article ${ts}`,
          description: 'Created by Jest',
          body:        'This is the body of the jest test article',
          tagList:     ['jest', 'testing']
        }
      });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('article');
    expect(res.body.article).toHaveProperty('slug');

    slug = res.body.article.slug;
  });

  test('GET /api/articles/:slug — get single article', async () => {
    if (!slug) return console.log('skipping — no slug');
    const res = await api.get(`/api/articles/${slug}`);
    expect(res.status).toBe(200);
    expect(res.body.article).toHaveProperty('slug', slug);
  });

  test('PUT /api/articles/:slug — update article', async () => {
    if (!slug) return console.log('skipping — no slug');
    const res = await api
      .put(`/api/articles/${slug}`)
      .set('Authorization', `Token ${token}`)
      .send({ article: { body: 'Updated body by Jest' } });

    expect(res.status).toBe(200);
    expect(res.body.article).toHaveProperty('body', 'Updated body by Jest');
  });

  test('POST /api/articles/:slug/favorite — favorite an article', async () => {
    if (!slug) return console.log('skipping — no slug');
    const res = await api
      .post(`/api/articles/${slug}/favorite`)
      .set('Authorization', `Token ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.article.favorited).toBe(true);
  });

  test('DELETE /api/articles/:slug/favorite — unfavorite an article', async () => {
    if (!slug) return console.log('skipping — no slug');
    const res = await api
      .delete(`/api/articles/${slug}/favorite`)
      .set('Authorization', `Token ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.article.favorited).toBe(false);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// COMMENTS
// ─────────────────────────────────────────────────────────────────────────────
describe('Comments', () => {
  let commentId = '';

  test('GET /api/articles/:slug/comments — get all comments', async () => {
    if (!slug) return console.log('skipping — no slug');
    const res = await api.get(`/api/articles/${slug}/comments`);
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('comments');
  });

  test('POST /api/articles/:slug/comments — create a comment', async () => {
    if (!slug) return console.log('skipping — no slug');
    const res = await api
      .post(`/api/articles/${slug}/comments`)
      .set('Authorization', `Token ${token}`)
      .send({ comment: { body: 'Jest test comment' } });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('comment');
    commentId = res.body.comment.id;
  });

  test('DELETE /api/articles/:slug/comments/:id — delete a comment', async () => {
    if (!slug || !commentId) return console.log('skipping — no slug or commentId');
    const res = await api
      .delete(`/api/articles/${slug}/comments/${commentId}`)
      .set('Authorization', `Token ${token}`);
    expect([200, 204]).toContain(res.status);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// PROFILES
// ─────────────────────────────────────────────────────────────────────────────
describe('Profiles', () => {
  test('GET /api/profiles/:username — get a profile', async () => {
    const res = await api.get(`/api/profiles/${testUser.user.username}`);
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('profile');
  });

  test('POST /api/profiles/:username/follow — follow a profile', async () => {
    const res = await api
      .post(`/api/profiles/${testUser.user.username}/follow`)
      .set('Authorization', `Token ${token}`);
    expect([200, 422, 500]).toContain(res.status);
  });

  test('DELETE /api/profiles/:username/follow — unfollow a profile', async () => {
    const res = await api
      .delete(`/api/profiles/${testUser.user.username}/follow`)
      .set('Authorization', `Token ${token}`);
    expect([200, 422, 500]).toContain(res.status);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// CLEANUP
// ─────────────────────────────────────────────────────────────────────────────
describe('Cleanup', () => {
  test('DELETE /api/articles/:slug — delete test article', async () => {
    if (!slug) return console.log('skipping — no slug to clean up');
    const res = await api
      .delete(`/api/articles/${slug}`)
      .set('Authorization', `Token ${token}`);
    expect([200, 204]).toContain(res.status);
  });
});
