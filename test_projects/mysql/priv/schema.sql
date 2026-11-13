create table tinyints (id int not null auto_increment primary key, value tinyint not null, nullable_value tinyint);
create table integers (id int not null auto_increment primary key, value int not null, nullable_value int);
create table unsigneds (id int not null auto_increment primary key, value int unsigned not null, nullable_value int unsigned);
create table bigints (id int not null auto_increment primary key, value bigint not null, nullable_value bigint);
create table floats (id int not null auto_increment primary key, value float not null, nullable_value float);
create table doubles (id int not null auto_increment primary key, value double not null, nullable_value double);
create table decimals (id int not null auto_increment primary key, value decimal(10, 2) not null, nullable_value decimal(10, 2));
create table varchars (id int not null auto_increment primary key, value varchar(10) not null, nullable_value varchar(10));
create table texts (id int not null auto_increment primary key, value text not null, nullable_value text);
create table blobs (id int not null auto_increment primary key, value blob not null, nullable_value blob);
create table booleans (id int not null auto_increment primary key, value tinyint(1) not null, nullable_value tinyint(1));
create table dates (id int not null auto_increment primary key, value date not null, nullable_value date);
create table datetimes (id int not null auto_increment primary key, value datetime not null, nullable_value datetime);
create table timestamps (id int not null auto_increment primary key, value timestamp not null, nullable_value timestamp);
create table times (id int not null auto_increment primary key, value time not null, nullable_value time);
create table jsons (id int not null auto_increment primary key, value json not null, nullable_value json);
create table moods (id int not null auto_increment primary key, value enum('happy', 'sad') not null, nullable_value enum('glad', 'mad'));
create table slices (value int not null);

-- https://github.com/daniellionel01/parrot/issues/74
create table keywords (id int not null auto_increment primary key, `type` text not null, `case` text not null);
