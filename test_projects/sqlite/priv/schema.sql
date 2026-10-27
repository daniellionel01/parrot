create table integers (value integer not null, nullable_value integer);
create table reals (value real not null, nullable_value real);
create table numerics (value numeric not null, nullable_value numeric);
create table texts (value text not null, nullable_value text);
create table varchars (value varchar(10) not null, nullable_value varchar(10));
create table blobs (value blob not null, nullable_value blob);
create table booleans (value boolean not null, nullable_value boolean);
create table dates (value date not null, nullable_value date);
create table datetimes (value datetime not null, nullable_value datetime);
create table timestamps (value timestamp not null, nullable_value timestamp);
create table times (value time not null, nullable_value time);

create table slices (value integer not null);

-- https://github.com/daniellionel01/parrot/issues/74
create table keywords ("type" text not null, "case" text not null);
