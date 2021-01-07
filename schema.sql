CREATE TABLE users (
  id serial PRIMARY KEY,
  time_zone integer NOT NULL CHECK (time_zone BETWEEN -12 AND 12),
  username text NOT NULL,
  password text
);

CREATE TABLE cycles (
  id serial PRIMARY KEY,
  user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  focus_start timestamp NOT NULL,
  rest_start timestamp NOT NULL,
  rest_end timestamp NOT NULL,
  duration time NOT NULL
);

INSERT INTO users (id, time_zone, username, password)
VALUES (0, 0, 'guest', '$2a$12$vj8PJkq2eKMjfrLF7X/eXuVk1h0EJ0ApBoiF0jw1PFos1jL7hriVK');
