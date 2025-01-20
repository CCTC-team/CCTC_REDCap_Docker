# Add users with Password = Testing123
# Users = test_user1, test_user2, test_user3, test_user4, test_admin, test_monitor, test_dm, test_de1, test_de2, test_de3, test_depi
# All users have the same password: Testing123

USE redcap;

INSERT INTO redcap_user_information (ui_id, username, user_email, user_firstname, user_lastname, super_user, account_manager, access_system_config, access_external_module_install, admin_rights, access_admin_dashboards) VALUES
(2,'test_user1','Test_User1@test.edu','Test','User1', 0, 0, 0, 0, 0, 0),
(3,'test_user2','Test_User2@test.edu','Test','User2', 0, 0, 0, 0, 0, 0),
(4,'test_user3','Test_User3@test.edu','Test','User3', 0, 0, 0, 0, 0, 0),
(5,'test_user4','Test_User4@test.edu','Test','User4', 0, 0, 0, 0, 0, 0),
(6,'test_admin','test_admin@test.edu','Admin','User', 1, 1, 1, 1, 1, 1),
(7,'test_monitor','test_monitor@test.edu','Test','Monitor', 0, 0, 0, 0, 0, 0),
(8,'test_dm','test_dm@test.edu','Test','DM', 0, 0, 0, 0, 0, 0),
(9,'test_de1','test_de1@test.edu','Test','DE1', 0, 0, 0, 0, 0, 0),
(10,'test_de2','test_de2@test.edu','Test','DE2', 0, 0, 0, 0, 0, 0),
(11,'test_de3','test_de3@test.edu','Test','DE3', 0, 0, 0, 0, 0, 0),
(12,'test_depi','test_depi@test.edu','Test','DEPI', 0, 0, 0, 0, 0, 0);

INSERT INTO redcap_auth (username, password, password_salt, legacy_hash, temp_pwd, password_question) 
VALUES 
('test_user1','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_user2','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_user3','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_user4','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_admin','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_monitor','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_dm','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_de1','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_de2','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_de3','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2),
('test_depi','041a2000c14ebefc3fc334cc02dfce4ca4f3552a48f8e2b37c928089d5f7487c52cdc79c90fde50a0ac3a17d1424681fc82c02d2f56f7bb93e315a2e90b4308f','dnuX#SD.#tCve5IjqYB-ueI~D~NFVyIow!xKbW-vM5-aHASdBdDSAja@3j~jkhWyuerjdt22X$W$o&hEY&bK%ojr-AVr4o*kE6cT',0,0,2);