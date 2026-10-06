-- 운영의 db-bootstrap Job(modules/environment/services.tf)과 같은 스키마
CREATE DATABASE IF NOT EXISTS `account` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `order` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS `product` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
