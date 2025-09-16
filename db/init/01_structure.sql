
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `admins`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `admins` (
  `id` int NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL DEFAULT '',
  `encrypted_password` varchar(255) NOT NULL DEFAULT '',
  `first_name` varchar(255) NOT NULL DEFAULT '',
  `last_name` varchar(255) NOT NULL DEFAULT '',
  `reset_password_token` varchar(255) DEFAULT NULL,
  `reset_password_sent_at` datetime DEFAULT NULL,
  `remember_created_at` datetime DEFAULT NULL,
  `sign_in_count` int NOT NULL DEFAULT '0',
  `current_sign_in_at` datetime DEFAULT NULL,
  `last_sign_in_at` datetime DEFAULT NULL,
  `current_sign_in_ip` varchar(255) DEFAULT NULL,
  `last_sign_in_ip` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_admins_on_email` (`email`) USING BTREE,
  UNIQUE KEY `index_admins_on_reset_password_token` (`reset_password_token`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `age_ranges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `age_ranges` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `windows_type_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_age_ranges_on_windows_type_id` (`windows_type_id`) USING BTREE,
  CONSTRAINT `fk_rails_c024608b8a` FOREIGN KEY (`windows_type_id`) REFERENCES `windows_types` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `answer_options`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `answer_options` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `order` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ar_internal_metadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ar_internal_metadata` (
  `key` varchar(255) NOT NULL,
  `value` varchar(255) DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL,
  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `attachments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attachments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `owner_id` int DEFAULT NULL,
  `owner_type` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `file_file_name` varchar(255) DEFAULT NULL,
  `file_content_type` varchar(255) DEFAULT NULL,
  `file_file_size` int DEFAULT NULL,
  `file_updated_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `banners`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `banners` (
  `id` int NOT NULL AUTO_INCREMENT,
  `content` text,
  `show` tinyint(1) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bookmark_annotations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bookmark_annotations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `bookmark_id` int DEFAULT NULL,
  `annotation` mediumtext,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_bookmark_annotations_on_bookmark_id` (`bookmark_id`) USING BTREE,
  CONSTRAINT `fk_rails_4a0149958f` FOREIGN KEY (`bookmark_id`) REFERENCES `bookmarks` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `bookmarks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `bookmarks` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int DEFAULT NULL,
  `bookmarkable_type` varchar(255) DEFAULT NULL,
  `bookmarkable_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_bookmarks_on_user_id` (`user_id`) USING BTREE,
  CONSTRAINT `fk_rails_c1ff6fa4ac` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `categories` (
  `id` int NOT NULL AUTO_INCREMENT,
  `metadatum_id` int DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `legacy_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `published` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_categories_on_metadatum_id` (`metadatum_id`) USING BTREE,
  CONSTRAINT `fk_rails_2a39ad5543` FOREIGN KEY (`metadatum_id`) REFERENCES `metadata` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `categorizable_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `categorizable_items` (
  `id` int NOT NULL AUTO_INCREMENT,
  `categorizable_id` int DEFAULT NULL,
  `categorizable_type` varchar(255) DEFAULT NULL,
  `category_id` int DEFAULT NULL,
  `legacy_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `inactive` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `index_categorizable_items_on_category_id` (`category_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ckeditor_assets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ckeditor_assets` (
  `id` int NOT NULL AUTO_INCREMENT,
  `data_file_name` varchar(255) NOT NULL,
  `data_content_type` varchar(255) DEFAULT NULL,
  `data_file_size` int DEFAULT NULL,
  `assetable_id` int DEFAULT NULL,
  `assetable_type` varchar(30) DEFAULT NULL,
  `type` varchar(30) DEFAULT NULL,
  `width` int DEFAULT NULL,
  `height` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `actual_url` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_ckeditor_assetable` (`assetable_type`,`assetable_id`) USING BTREE,
  KEY `idx_ckeditor_assetable_type` (`assetable_type`,`type`,`assetable_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `faqs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `faqs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `question` varchar(255) DEFAULT NULL,
  `answer` mediumtext,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `inactive` tinyint(1) DEFAULT NULL,
  `ordering` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `footers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `footers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `phone` varchar(255) DEFAULT NULL,
  `children_program` varchar(255) DEFAULT NULL,
  `adult_program` varchar(255) DEFAULT NULL,
  `general_questions` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `form_builders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `form_builders` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `owner_type` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `description` mediumtext,
  `windows_type_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_form_builders_on_windows_type_id` (`windows_type_id`) USING BTREE,
  CONSTRAINT `fk_rails_7c0d5eddf5` FOREIGN KEY (`windows_type_id`) REFERENCES `windows_types` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `form_field_answer_options`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `form_field_answer_options` (
  `id` int NOT NULL AUTO_INCREMENT,
  `form_field_id` int DEFAULT NULL,
  `answer_option_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_form_field_answer_options_on_answer_option_id` (`answer_option_id`) USING BTREE,
  KEY `index_form_field_answer_options_on_form_field_id` (`form_field_id`) USING BTREE,
  CONSTRAINT `fk_rails_cd209ba980` FOREIGN KEY (`answer_option_id`) REFERENCES `answer_options` (`id`),
  CONSTRAINT `fk_rails_ebd54d061b` FOREIGN KEY (`form_field_id`) REFERENCES `form_fields` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `form_fields`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `form_fields` (
  `id` int NOT NULL AUTO_INCREMENT,
  `form_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `question` varchar(255) DEFAULT NULL,
  `instructional_hint` varchar(255) DEFAULT NULL,
  `answer_type` int DEFAULT NULL,
  `answer_datatype` int DEFAULT NULL,
  `ordering` int DEFAULT NULL,
  `is_required` tinyint(1) DEFAULT '1',
  `status` int DEFAULT '1',
  `parent_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_form_fields_on_form_id` (`form_id`) USING BTREE,
  CONSTRAINT `fk_rails_28fb260032` FOREIGN KEY (`form_id`) REFERENCES `forms` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `forms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `forms` (
  `id` int NOT NULL AUTO_INCREMENT,
  `owner_type` varchar(255) DEFAULT NULL,
  `owner_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `form_builder_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_forms_on_form_builder_id` (`form_builder_id`) USING BTREE,
  CONSTRAINT `fk_rails_fce8ef6c09` FOREIGN KEY (`form_builder_id`) REFERENCES `form_builders` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `images`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `images` (
  `id` int NOT NULL AUTO_INCREMENT,
  `owner_id` int DEFAULT NULL,
  `owner_type` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `file_file_name` varchar(255) DEFAULT NULL,
  `file_content_type` varchar(255) DEFAULT NULL,
  `file_file_size` int DEFAULT NULL,
  `file_updated_at` datetime DEFAULT NULL,
  `report_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_images_on_owner_id` (`owner_id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `locations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `locations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `city` varchar(255) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `country` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `media_files`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `media_files` (
  `id` int NOT NULL AUTO_INCREMENT,
  `file_file_name` varchar(255) DEFAULT NULL,
  `file_content_type` varchar(255) DEFAULT NULL,
  `file_file_size` int DEFAULT NULL,
  `file_updated_at` datetime DEFAULT NULL,
  `report_id` int DEFAULT NULL,
  `workshop_log_id` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `metadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `metadata` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `legacy_id` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `published` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `monthly_reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `monthly_reports` (
  `id` int NOT NULL AUTO_INCREMENT,
  `month` varchar(255) DEFAULT NULL,
  `project_id` int DEFAULT NULL,
  `project_user_id` int DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `position` varchar(255) DEFAULT NULL,
  `mail_evaluations` tinyint(1) DEFAULT NULL,
  `num_ongoing_participants` varchar(255) DEFAULT NULL,
  `num_new_participants` varchar(255) DEFAULT NULL,
  `most_effective` mediumtext,
  `most_challenging` mediumtext,
  `goals_reached` mediumtext,
  `goals` mediumtext,
  `comments` mediumtext,
  `call_requested` tinyint(1) DEFAULT NULL,
  `best_call_time` varchar(255) DEFAULT NULL,
  `phone` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_monthly_reports_on_project_id` (`project_id`) USING BTREE,
  KEY `index_monthly_reports_on_project_user_id` (`project_user_id`) USING BTREE,
  CONSTRAINT `fk_rails_2b3e10db1b` FOREIGN KEY (`project_user_id`) REFERENCES `project_users` (`id`),
  CONSTRAINT `fk_rails_e0346a025f` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` int NOT NULL AUTO_INCREMENT,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `notification_type` int DEFAULT NULL,
  `noticeable_type` varchar(255) DEFAULT NULL,
  `noticeable_id` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `permissions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `security_cat` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `legacy_id` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `project_obligations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_obligations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `project_statuses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_statuses` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `project_users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `project_users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `agency_id` int DEFAULT NULL,
  `user_id` int DEFAULT NULL,
  `position` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `project_id` int DEFAULT NULL,
  `filemaker_code` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_project_users_on_agency_id` (`agency_id`) USING BTREE,
  KEY `index_project_users_on_project_id` (`project_id`) USING BTREE,
  KEY `index_project_users_on_user_id` (`user_id`) USING BTREE,
  CONSTRAINT `fk_rails_1bf16ed5d0` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
  CONSTRAINT `fk_rails_6263f34d35` FOREIGN KEY (`agency_id`) REFERENCES `projects` (`id`),
  CONSTRAINT `fk_rails_996d73fecd` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `projects`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `projects` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `location_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `windows_type_id` int DEFAULT NULL,
  `district` varchar(255) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `locality` varchar(255) DEFAULT NULL,
  `description` mediumtext,
  `notes` mediumtext,
  `filemaker_code` varchar(255) DEFAULT NULL,
  `inactive` tinyint(1) DEFAULT '0',
  `legacy_id` int DEFAULT NULL,
  `legacy` tinyint(1) DEFAULT '0',
  `project_status_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_projects_on_location_id` (`location_id`) USING BTREE,
  KEY `index_projects_on_project_status_id` (`project_status_id`) USING BTREE,
  KEY `index_projects_on_windows_type_id` (`windows_type_id`) USING BTREE,
  CONSTRAINT `fk_rails_626ce752d1` FOREIGN KEY (`windows_type_id`) REFERENCES `windows_types` (`id`),
  CONSTRAINT `fk_rails_9a8c72b8ef` FOREIGN KEY (`project_status_id`) REFERENCES `project_statuses` (`id`),
  CONSTRAINT `fk_rails_b10c80c09a` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `quotable_item_quotes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `quotable_item_quotes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `quotable_type` varchar(255) DEFAULT NULL,
  `quotable_id` int DEFAULT NULL,
  `legacy_id` int DEFAULT NULL,
  `quote_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_quotable_item_quotes_on_quote_id` (`quote_id`) USING BTREE,
  CONSTRAINT `fk_rails_3248085d05` FOREIGN KEY (`quote_id`) REFERENCES `quotes` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `quotes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `quotes` (
  `id` int NOT NULL AUTO_INCREMENT,
  `quote` mediumtext,
  `inactive` tinyint(1) DEFAULT '1',
  `legacy_id` int DEFAULT NULL,
  `legacy` tinyint(1) DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `workshop_id` int DEFAULT NULL,
  `age` varchar(255) DEFAULT NULL,
  `gender` varchar(1) DEFAULT NULL,
  `speaker_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_quotes_on_workshop_id` (`workshop_id`) USING BTREE,
  CONSTRAINT `fk_rails_a8a4fa9353` FOREIGN KEY (`workshop_id`) REFERENCES `workshops` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `report_form_field_answers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `report_form_field_answers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `report_id` int DEFAULT NULL,
  `form_field_id` int DEFAULT NULL,
  `answer` mediumtext,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `answer_option_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_report_form_field_answers_on_answer_option_id` (`answer_option_id`) USING BTREE,
  KEY `index_report_form_field_answers_on_form_field_id` (`form_field_id`) USING BTREE,
  KEY `index_report_form_field_answers_on_report_id` (`report_id`) USING BTREE,
  CONSTRAINT `fk_rails_1758f56630` FOREIGN KEY (`answer_option_id`) REFERENCES `answer_options` (`id`),
  CONSTRAINT `fk_rails_523cca41ec` FOREIGN KEY (`form_field_id`) REFERENCES `form_fields` (`id`),
  CONSTRAINT `fk_rails_59f465a617` FOREIGN KEY (`report_id`) REFERENCES `reports` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reports` (
  `id` int NOT NULL AUTO_INCREMENT,
  `type` varchar(255) DEFAULT NULL,
  `owner_id` int DEFAULT NULL,
  `owner_type` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `user_id` int DEFAULT NULL,
  `project_id` int DEFAULT NULL,
  `date` date DEFAULT NULL,
  `rating` int DEFAULT '0',
  `windows_type_id` int DEFAULT NULL,
  `form_file_file_name` varchar(255) DEFAULT NULL,
  `form_file_content_type` varchar(255) DEFAULT NULL,
  `form_file_file_size` int DEFAULT NULL,
  `form_file_updated_at` datetime DEFAULT NULL,
  `workshop_id` int DEFAULT NULL,
  `workshop_name` varchar(255) DEFAULT NULL,
  `other_description` varchar(255) DEFAULT NULL,
  `has_attachment` tinyint(1) DEFAULT '0',
  `children_first_time` int DEFAULT '0',
  `children_ongoing` int DEFAULT '0',
  `teens_first_time` int DEFAULT '0',
  `teens_ongoing` int DEFAULT '0',
  `adults_first_time` int DEFAULT '0',
  `adults_ongoing` int DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_reports_on_project_id` (`project_id`) USING BTREE,
  KEY `index_reports_on_user_id` (`user_id`) USING BTREE,
  KEY `index_reports_on_windows_type_id` (`windows_type_id`) USING BTREE,
  CONSTRAINT `fk_rails_9a0a9c9bec` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`),
  CONSTRAINT `fk_rails_c7699d537d` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_cad34354d2` FOREIGN KEY (`windows_type_id`) REFERENCES `windows_types` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `resources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `resources` (
  `id` int NOT NULL AUTO_INCREMENT,
  `title` varchar(255) DEFAULT NULL,
  `author` varchar(255) DEFAULT NULL,
  `user_id` int DEFAULT NULL,
  `text` mediumtext,
  `featured` tinyint(1) DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `kind` varchar(255) DEFAULT NULL,
  `workshop_id` int DEFAULT NULL,
  `male` tinyint(1) DEFAULT '0',
  `female` tinyint(1) DEFAULT '0',
  `url` varchar(255) DEFAULT NULL,
  `inactive` tinyint(1) DEFAULT '1',
  `agency` varchar(255) DEFAULT NULL,
  `legacy` tinyint(1) DEFAULT NULL,
  `windows_type_id` int DEFAULT NULL,
  `filemaker_code` varchar(255) DEFAULT NULL,
  `ordering` int DEFAULT NULL,
  `legacy_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_resources_on_user_id` (`user_id`) USING BTREE,
  KEY `index_resources_on_windows_type_id` (`windows_type_id`) USING BTREE,
  KEY `index_resources_on_workshop_id` (`workshop_id`) USING BTREE,
  CONSTRAINT `fk_rails_250ed64e61` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_25881b7145` FOREIGN KEY (`workshop_id`) REFERENCES `workshops` (`id`),
  CONSTRAINT `fk_rails_64d6312a4d` FOREIGN KEY (`windows_type_id`) REFERENCES `windows_types` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `schema_migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `schema_migrations` (
  `version` varchar(255) NOT NULL,
  PRIMARY KEY (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `sectorable_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sectorable_items` (
  `id` int NOT NULL AUTO_INCREMENT,
  `sectorable_id` int DEFAULT NULL,
  `sectorable_type` varchar(255) DEFAULT NULL,
  `sector_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `inactive` tinyint(1) DEFAULT '1',
  PRIMARY KEY (`id`),
  KEY `index_sectorable_items_on_sector_id` (`sector_id`) USING BTREE,
  CONSTRAINT `fk_rails_e07347a811` FOREIGN KEY (`sector_id`) REFERENCES `sectors` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `sectors`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sectors` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `published` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_form_form_fields`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_form_form_fields` (
  `id` int NOT NULL AUTO_INCREMENT,
  `form_field_id` int DEFAULT NULL,
  `user_form_id` int DEFAULT NULL,
  `text` mediumtext,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_user_form_form_fields_on_form_field_id` (`form_field_id`) USING BTREE,
  KEY `index_user_form_form_fields_on_user_form_id` (`user_form_id`) USING BTREE,
  CONSTRAINT `fk_rails_39d6f1f01b` FOREIGN KEY (`user_form_id`) REFERENCES `user_forms` (`id`),
  CONSTRAINT `fk_rails_7f65ef2823` FOREIGN KEY (`form_field_id`) REFERENCES `form_fields` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_forms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_forms` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int DEFAULT NULL,
  `form_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_user_forms_on_form_id` (`form_id`) USING BTREE,
  KEY `index_user_forms_on_user_id` (`user_id`) USING BTREE,
  CONSTRAINT `fk_rails_8043c5e46d` FOREIGN KEY (`form_id`) REFERENCES `forms` (`id`),
  CONSTRAINT `fk_rails_a0f04749a3` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `user_permissions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_permissions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int DEFAULT NULL,
  `permission_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_user_permissions_on_permission_id` (`permission_id`) USING BTREE,
  KEY `index_user_permissions_on_user_id` (`user_id`) USING BTREE,
  CONSTRAINT `fk_rails_b29e483ce4` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_e2cb0687d2` FOREIGN KEY (`permission_id`) REFERENCES `permissions` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL DEFAULT '',
  `encrypted_password` varchar(255) NOT NULL DEFAULT '',
  `first_name` varchar(255) DEFAULT '',
  `last_name` varchar(255) DEFAULT '',
  `reset_password_token` varchar(255) DEFAULT NULL,
  `reset_password_sent_at` datetime DEFAULT NULL,
  `remember_created_at` datetime DEFAULT NULL,
  `sign_in_count` int NOT NULL DEFAULT '0',
  `current_sign_in_at` datetime DEFAULT NULL,
  `last_sign_in_at` datetime DEFAULT NULL,
  `current_sign_in_ip` varchar(255) DEFAULT NULL,
  `last_sign_in_ip` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT NULL,
  `updated_at` datetime DEFAULT NULL,
  `agency_id` int DEFAULT NULL,
  `phone` varchar(255) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `city` varchar(255) DEFAULT NULL,
  `state` varchar(255) DEFAULT NULL,
  `zip` varchar(255) DEFAULT NULL,
  `birthday` date DEFAULT NULL,
  `subscribecode` varchar(255) DEFAULT NULL,
  `comment` mediumtext,
  `notes` mediumtext,
  `legacy` tinyint(1) DEFAULT '0',
  `inactive` tinyint(1) DEFAULT '0',
  `confirmed` tinyint(1) DEFAULT '1',
  `legacy_id` int DEFAULT NULL,
  `phone2` varchar(255) DEFAULT NULL,
  `phone3` varchar(255) DEFAULT NULL,
  `best_time_to_call` varchar(255) DEFAULT NULL,
  `address2` varchar(255) DEFAULT NULL,
  `city2` varchar(255) DEFAULT NULL,
  `state2` varchar(255) DEFAULT NULL,
  `zip2` varchar(255) DEFAULT NULL,
  `primary_address` int DEFAULT NULL,
  `avatar_file_name` varchar(255) DEFAULT NULL,
  `avatar_content_type` varchar(255) DEFAULT NULL,
  `avatar_file_size` int DEFAULT NULL,
  `avatar_updated_at` datetime DEFAULT NULL,
  `super_user` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `index_users_on_email` (`email`) USING BTREE,
  UNIQUE KEY `index_users_on_reset_password_token` (`reset_password_token`) USING BTREE,
  KEY `index_users_on_agency_id` (`agency_id`) USING BTREE,
  CONSTRAINT `fk_rails_627daf9bbe` FOREIGN KEY (`agency_id`) REFERENCES `projects` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `windows_types`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `windows_types` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `legacy_id` int DEFAULT NULL,
  `short_name` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `workshop_age_ranges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `workshop_age_ranges` (
  `id` int NOT NULL AUTO_INCREMENT,
  `workshop_id` int DEFAULT NULL,
  `age_range_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_workshop_age_ranges_on_age_range_id` (`age_range_id`) USING BTREE,
  KEY `index_workshop_age_ranges_on_workshop_id` (`workshop_id`) USING BTREE,
  CONSTRAINT `fk_rails_6b41027b34` FOREIGN KEY (`age_range_id`) REFERENCES `age_ranges` (`id`),
  CONSTRAINT `fk_rails_e15608e1ed` FOREIGN KEY (`workshop_id`) REFERENCES `workshops` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `workshop_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `workshop_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `workshop_id` int DEFAULT NULL,
  `user_id` int DEFAULT NULL,
  `date` date DEFAULT NULL,
  `rating` int DEFAULT '0',
  `reaction` mediumtext,
  `successes` mediumtext,
  `challenges` mediumtext,
  `suggestions` mediumtext,
  `questions` mediumtext,
  `lead_similar` tinyint(1) DEFAULT NULL,
  `similarities` mediumtext,
  `differences` mediumtext,
  `comments` mediumtext,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `project_id` int DEFAULT NULL,
  `is_embodied_art_workshop` tinyint(1) DEFAULT '0',
  `num_participants_on_going` int DEFAULT '0',
  `num_participants_first_time` int DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `index_workshop_logs_on_project_id` (`project_id`) USING BTREE,
  KEY `index_workshop_logs_on_user_id` (`user_id`) USING BTREE,
  KEY `index_workshop_logs_on_workshop_id` (`workshop_id`) USING BTREE,
  CONSTRAINT `fk_rails_2773ee292a` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`),
  CONSTRAINT `fk_rails_3b54ed3230` FOREIGN KEY (`workshop_id`) REFERENCES `workshops` (`id`),
  CONSTRAINT `fk_rails_9975099f24` FOREIGN KEY (`project_id`) REFERENCES `projects` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `workshop_resources`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `workshop_resources` (
  `id` int NOT NULL AUTO_INCREMENT,
  `workshop_id` int DEFAULT NULL,
  `resource_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `index_workshop_resources_on_resource_id` (`resource_id`) USING BTREE,
  KEY `index_workshop_resources_on_workshop_id` (`workshop_id`) USING BTREE,
  CONSTRAINT `fk_rails_0b9b541d1c` FOREIGN KEY (`workshop_id`) REFERENCES `workshops` (`id`),
  CONSTRAINT `fk_rails_ce079b942f` FOREIGN KEY (`resource_id`) REFERENCES `resources` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `workshop_variations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `workshop_variations` (
  `id` int NOT NULL AUTO_INCREMENT,
  `workshop_id` int DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `code` mediumtext,
  `inactive` tinyint(1) DEFAULT '1',
  `ordering` int DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `legacy` tinyint(1) DEFAULT '0',
  `variation_id` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `index_workshop_variations_on_workshop_id` (`workshop_id`) USING BTREE,
  CONSTRAINT `fk_rails_d25d5e6e42` FOREIGN KEY (`workshop_id`) REFERENCES `workshops` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `workshops`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `workshops` (
  `id` int NOT NULL AUTO_INCREMENT,
  `title` varchar(255) DEFAULT NULL,
  `full_name` varchar(255) DEFAULT NULL,
  `author_location` varchar(255) DEFAULT NULL,
  `month` int DEFAULT NULL,
  `year` int DEFAULT NULL,
  `objective` mediumtext,
  `materials` mediumtext,
  `timeframe` mediumtext,
  `age_range` mediumtext,
  `setup` mediumtext,
  `instructions` mediumtext,
  `warm_up` mediumtext,
  `creation` mediumtext,
  `closing` mediumtext,
  `misc_instructions` mediumtext,
  `project` mediumtext,
  `description` mediumtext,
  `notes` mediumtext,
  `timestamps` mediumtext,
  `tips` mediumtext,
  `pub_issue` varchar(255) DEFAULT NULL,
  `misc1` varchar(255) DEFAULT NULL,
  `misc2` varchar(255) DEFAULT NULL,
  `inactive` tinyint(1) DEFAULT '1',
  `searchable` tinyint(1) DEFAULT '0',
  `featured` tinyint(1) DEFAULT '0',
  `photo_caption` varchar(255) DEFAULT NULL,
  `filemaker_code` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `legacy` tinyint(1) DEFAULT '0',
  `legacy_id` int DEFAULT NULL,
  `windows_type_id` int DEFAULT NULL,
  `user_id` int DEFAULT NULL,
  `led_count` int DEFAULT '0',
  `objective_spanish` mediumtext,
  `materials_spanish` mediumtext,
  `timeframe_spanish` mediumtext,
  `age_range_spanish` mediumtext,
  `setup_spanish` mediumtext,
  `instructions_spanish` mediumtext,
  `project_spanish` mediumtext,
  `warm_up_spanish` mediumtext,
  `creation_spanish` mediumtext,
  `closing_spanish` mediumtext,
  `misc_instructions_spanish` mediumtext,
  `description_spanish` mediumtext,
  `notes_spanish` mediumtext,
  `tips_spanish` mediumtext,
  `thumbnail_file_name` varchar(255) DEFAULT NULL,
  `thumbnail_content_type` varchar(255) DEFAULT NULL,
  `thumbnail_file_size` int DEFAULT NULL,
  `thumbnail_updated_at` datetime DEFAULT NULL,
  `optional_materials` mediumtext,
  `optional_materials_spanish` mediumtext,
  `introduction` mediumtext,
  `introduction_spanish` mediumtext,
  `demonstration` mediumtext,
  `demonstration_spanish` mediumtext,
  `opening_circle` mediumtext,
  `opening_circle_spanish` mediumtext,
  `visualization` mediumtext,
  `visualization_spanish` mediumtext,
  `misc1_spanish` mediumtext,
  `misc2_spanish` mediumtext,
  `time_intro` int DEFAULT NULL,
  `time_demonstration` int DEFAULT NULL,
  `time_warm_up` int DEFAULT NULL,
  `time_creation` int DEFAULT NULL,
  `time_closing` int DEFAULT NULL,
  `time_opening` int DEFAULT NULL,
  `header_file_name` varchar(255) DEFAULT NULL,
  `header_content_type` varchar(255) DEFAULT NULL,
  `header_file_size` int DEFAULT NULL,
  `header_updated_at` datetime DEFAULT NULL,
  `extra_field` text,
  `extra_field_spanish` text,
  PRIMARY KEY (`id`),
  KEY `index_workshops_on_user_id` (`user_id`) USING BTREE,
  KEY `index_workshops_on_windows_type_id` (`windows_type_id`) USING BTREE,
  FULLTEXT KEY `workshop_fullsearch` (`title`,`full_name`,`objective`,`materials`,`introduction`,`demonstration`,`opening_circle`,`warm_up`,`creation`,`closing`,`notes`,`tips`,`misc1`,`misc2`),
  FULLTEXT KEY `workshop_fullsearch_title` (`title`),
  CONSTRAINT `fk_rails_a14638d2bb` FOREIGN KEY (`windows_type_id`) REFERENCES `windows_types` (`id`),
  CONSTRAINT `fk_rails_e39f638ece` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

INSERT INTO `schema_migrations` (version) VALUES
('20250407002246');


