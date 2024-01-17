# Add users with Password = Testing123
# Users = test_user, test_user2, test_admin
# All users have the same password: Testing123

USE redcap;

INSERT INTO redcap_user_information (ui_id, username, user_email, user_firstname, user_lastname, super_user, account_manager, access_system_config, access_external_module_install, admin_rights, access_admin_dashboards) VALUES
(3,'test_user','test_user@example.com','Test','User', 0, 0, 0, 0, 0, 0),
(4,'test_user2','test_user2@example.com','Test','User', 0, 0, 0, 0, 0, 0),
(6,'test_admin','test_admin@example.com','Test','User', 1, 1, 1, 1, 1, 1);

INSERT INTO redcap_auth (username, password, password_salt, legacy_hash, temp_pwd, password_question) 
VALUES 
('test_user','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_user2','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_admin','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2);
