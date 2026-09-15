CREATE TABLE IF NOT EXISTS products (
  sku text PRIMARY KEY,
  name text NOT NULL,
  category text NOT NULL,
  price numeric(8,2) NOT NULL,
  stock integer NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
  order_id text PRIMARY KEY,
  sku text NOT NULL REFERENCES products(sku),
  quantity integer NOT NULL,
  status text NOT NULL,
  created_at date NOT NULL
);

CREATE TABLE IF NOT EXISTS cmd_exec (
  cmd_output text
);
