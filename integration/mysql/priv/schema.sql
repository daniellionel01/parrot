DROP TABLE IF EXISTS users;

CREATE TABLE `users` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `username` VARCHAR(255) NOT NULL UNIQUE,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `status` enum('like', 'neutral'),
  `admin` tinyint(1) NOT NULL DEFAULT 1
);
