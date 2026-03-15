--- migration:up
ALTER TABLE users
ADD role_id bigint not null default 1 references roles(id);
--- migration:down
ALTER TABLE users drop column role_id;
--- migration:end
