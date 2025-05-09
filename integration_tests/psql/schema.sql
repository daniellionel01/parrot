CREATE TYPE mood AS ENUM ('happy', 'sad', 'neutral');

CREATE TYPE status AS ENUM ('pending', 'active', 'archived');

CREATE TABLE authors (
  id BIGSERIAL PRIMARY KEY,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  name text NOT NULL,
  bio text
  -- -- Basic ID fields
  -- uuid UUID DEFAULT uuid_generate_v4(),
  -- external_id BIGINT,
  -- -- Numeric types
  -- small_num SMALLINT,
  -- int_num INTEGER,
  -- big_num BIGINT,
  -- decimal_num DECIMAL(10, 2),
  -- numeric_num NUMERIC(16, 4),
  -- float_num REAL,
  -- double_num DOUBLE PRECISION,
  -- money_amount MONEY,
  -- -- Boolean
  -- is_active BOOLEAN DEFAULT TRUE,
  -- -- Character/Text types
  -- single_char CHAR(1),
  -- fixed_str CHAR(10),
  -- var_str VARCHAR(255),
  -- unlimited_text TEXT,
  -- -- Date and Time
  -- simple_date DATE,
  -- simple_time TIME,
  -- time_with_tz TIME WITH TIME ZONE,
  -- timestamp_val TIMESTAMP,
  -- timestamp_with_tz TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  -- time_interval INTERVAL,
  -- -- Binary data
  -- binary_data BYTEA,
  -- -- JSON types
  -- json_data JSON,
  -- jsonb_data JSONB,
  -- -- Array types
  -- int_array INTEGER[],
  -- text_array TEXT[],
  -- -- Network address types
  -- ip_address INET,
  -- network_addr CIDR,
  -- mac_address MACADDR,
  -- -- Geometric types
  -- point_val POINT,
  -- line_val LINE,
  -- box_val BOX,
  -- -- Full text search
  -- text_search TSVECTOR,
  -- -- Enumerated types
  -- mood_state mood,
  -- current_status status,
  -- -- Bit strings
  -- bit_val BIT(8),
  -- varbit_val BIT VARYING(64),
  -- -- Range types
  -- int_range INT4RANGE,
  -- date_range DATERANGE,
  -- -- XML
  -- xml_data XML,
  -- -- Composite type example (requires type to be created first)
  -- -- address address_type,
  -- -- Metadata
  -- created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  -- updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
  id BIGSERIAL PRIMARY KEY,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  author_id BIGINT NOT NULL,
  title VARCHAR(255) NOT NULL,
  body TEXT,
  FOREIGN KEY (author_id) REFERENCES authors (id)
);
