#Manages the commerce for a chain of small vendors. 
#Implemented with forward engineering. 

DROP SCHEMA IF EXISTS `VendorDB`;
CREATE SCHEMA `VendorDB`;
USE `VendorDB` ;

#Item. Items that the vendor sells.
CREATE TABLE IF NOT EXISTS `VendorDB`.`ITEM` (
  `ItemID` INT NOT NULL AUTO_INCREMENT,
  `Name` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`ItemID`));

#User. User can be an admin, vendor, or customer.
CREATE TABLE IF NOT EXISTS `VendorDB`.`USER` (
  `UserID` INT NOT NULL AUTO_INCREMENT,
  `firstname` VARCHAR(45) NOT NULL,
  `lastname` VARCHAR(45) NOT NULL,
  `email` VARCHAR(45) NOT NULL,
  `password` VARCHAR(45) NOT NULL,
  `usertype` ENUM('admin', 'vendor', 'customer') NOT NULL,
  PRIMARY KEY (`UserID`));
  
#Location. The location of a vendor's store. I implement a 
#cascading update because want to update the fkID if we 
#change the user PK. Restrict delete because location must 
#have a user.
CREATE TABLE IF NOT EXISTS `VendorDB`.`LOCATION` (
  `LocationID` INT NOT NULL AUTO_INCREMENT,
  `VendorName` VARCHAR(45) NULL,
  `Availability` ENUM('Y', 'N') NOT NULL,
  `Address` VARCHAR(45) NOT NULL,
  `UserID` INT NOT NULL,
  `Lat` DECIMAL(10,8) NULL,
  `Long` DECIMAL(11,8) NULL,
  `Hours` VARCHAR(45) NULL,
  `Phone` VARCHAR(45) NULL,
  PRIMARY KEY (`LocationID`),
  CONSTRAINT `fk_Location_User`
    FOREIGN KEY (`UserID`)
    REFERENCES `VendorDB`.`USER` (`UserID`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE);
    
#Order. Orders received by a vendor location. I implement a 
#cascading update because want to update the fkID if we change 
#the location PK I want to restrict deleting locations that have 
#orders associated with them. 
CREATE TABLE IF NOT EXISTS `VendorDB`.`ORDER` (
  `OrderID` INT NOT NULL AUTO_INCREMENT,
  `LocationID` INT NOT NULL,
  `Status` ENUM('Received', 'Fulfilled') NOT NULL,
  `Time` DATETIME NOT NULL,
  PRIMARY KEY (`OrderID`, `LocationID`),
  CONSTRAINT `fk_Order_Location`
    FOREIGN KEY (`LocationID`)
    REFERENCES `VendorDB`.`LOCATION` (`LocationID`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE);
    
#Log. This log tracks changes made such as item availability (menu_availability),
#changes to location availability (location_availabilty), changes to the location's
#address (location_address), and if a new location is added (location_add). It is
#added to by triggers when a user updates or adds to the relevant tables. I implement 
#a cascading update because want to update the fkID if we change the user PK
#Restrict delete if we have a log of item or location.
CREATE TABLE IF NOT EXISTS `VendorDB`.`LOG` (
  `ChangeID` INT NOT NULL AUTO_INCREMENT,
  `Type` ENUM('LOCATION_ADD', 'LOCATION_AVAILABILITY', 'LOCATION_ADDRESS', 'MENU_AVAILABILITY') NOT NULL,
  `Original_Availability` ENUM('Y', 'N') NULL,
  `New_Availability` ENUM('Y', 'N') NULL,
  `Time` DATETIME NOT NULL,
  `Original_Address` VARCHAR(45) NULL,
  `New_Address` VARCHAR(45) NULL,
  `LocationID` INT NOT NULL,
  `ItemID` INT NULL,
  PRIMARY KEY (`ChangeID`),
  CONSTRAINT `fk_Log_Location`
  FOREIGN KEY (`LocationID`)
    REFERENCES `VendorDB`.`LOCATION` (`LocationID`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Log_Item`
  FOREIGN KEY (`ItemID`)
    REFERENCES `VendorDB`.`Item` (`ItemID`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE);
    
#Order_Item. These are the items associated with an order. There can be many items, hence the 
#linking table. We shouldn't be able to delete an item if its associated with any orders. 
#ON DELETE RESTRICT is thus logical However if we want to delete the an order then that 
#should cascade delete the order items. 
CREATE TABLE IF NOT EXISTS `VendorDB`.`Order_Item` (
  `ItemID` INT NOT NULL,
  `OrderID` INT NOT NULL,
  `LocationID` INT NOT NULL,
  `Quantity` INT NOT NULL,
  PRIMARY KEY (`ItemID`, `OrderID`, `LocationID`),
  CONSTRAINT `fk_ORDER_ITEM`
    FOREIGN KEY (`ItemID`)
    REFERENCES `VendorDB`.`ITEM` (`ItemID`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE,
  CONSTRAINT `fk_ITEM_has_ORDER_ORDER1`
    FOREIGN KEY (`OrderID` , `LocationID`)
    REFERENCES `VendorDB`.`ORDER` (`OrderID` , `LocationID`)
    ON DELETE CASCADE
    ON UPDATE CASCADE);
    
#Location_Item. We shouldn't be able to delete an item if its associated with any locations. 
#ON DELETE RESTRICT is thus logical. However if we want to delete the location then that 
#should cascade delete the corresponding location items. 

CREATE TABLE IF NOT EXISTS `VendorDB`.`LOCATION_ITEM` (
  `LocationID` INT NOT NULL,
  `ItemID` INT NOT NULL,
  `Availability` ENUM('Y', 'N') NOT NULL,
  `Quantity` INT NOT NULL,
  PRIMARY KEY (`LocationID`, `ItemID`),
  CONSTRAINT `fk_ITEM_LOCATION`
    FOREIGN KEY (`LocationID`)
    REFERENCES `VendorDB`.`LOCATION` (`LocationID`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_LOCATION_has_ITEM_ITEM1`
    FOREIGN KEY (`ItemID`)
    REFERENCES `VendorDB`.`ITEM` (`ItemID`)
    ON DELETE RESTRICT
    ON UPDATE CASCADE);

#----------------------Procedures-----------------------
#These are several procedures to make it easier to retrieve information from the database. I used
#procedures as opposed to views because procedures get updated when the database is added or updated.

#Shows the log of changes.
DELIMITER //
CREATE PROCEDURE ShowLog()
	BEGIN
	SELECT `Type` AS 'Change_Type',
			`Time` AS 'Time', 
			Original_Availability AS 'Original_Availability',
            New_Availability AS 'New_Availability',
            Original_Address AS 'Original_Address',
            New_Address AS 'New_Address',
			Location.VendorName AS 'Location',
            ItemID AS 'Item'
	 FROM LOG
     JOIN LOCATION USING(LocationID)
     ORDER BY `Time` DESC;
END //

#Shows all the locations.
DELIMITER //
CREATE PROCEDURE ShowLocation()
BEGIN
	SELECT LOCATION.VendorName AS 'VendorName',
    LOCATION.Address AS 'Address', 
    LOCATION.Availability AS 'Available',
    LOCATION.Lat AS 'Lat',
    LOCATION.`Long` AS 'Long',
    LOCATION.Hours AS 'Hours',
    LOCATION.Phone AS 'Phone'
FROM LOCATION
ORDER BY Location.VendorName DESC;
END //

#Shows all the orders.
DELIMITER //
CREATE PROCEDURE ShowOrder()
BEGIN
	SELECT `ORDER`.`Status` AS 'OrderStatus',
    `ORDER`.`TIME` AS 'TimeReceived',
    `Location`.VendorName'LocationName',
    `Item`.`Name` AS 'Item',
    ORDER_Item.Quantity AS 'Quantity'
    FROM `ORDER` 
		JOIN LOCATION USING(LocationID) 
        JOIN Order_Item USING(OrderID) 
        JOIN ITEM USING(ItemID) 
	ORDER BY OrderID;
END //

#Shows all the menu items. 
DELIMITER //
CREATE PROCEDURE ShowMenu()
BEGIN
	SELECT 
    LOCATION.VendorName AS 'VendorName',
    ITEM.`Name` AS 'Item', 
    LOCATION_ITEM.Quantity AS 'Quantity',
    LOCATION_ITEM.Availability AS 'Availability'
    FROM LOCATION
		JOIN LOCATION_ITEM USING(LocationID)
        JOIN ITEM USING(ItemID);
END //


#----------------------TRIGGERS-----------------------
#These triggers add to the log table when changes are made to tables that we want to track. 
#For example if a user adds a new location, the trigger adds a new log indicating a location was added

#Adds new log indicating a location was added. 
DELIMITER //
CREATE TRIGGER LOCATION_ADD AFTER INSERT ON LOCATION
	FOR EACH ROW
	BEGIN
	  INSERT INTO LOG (ChangeID, `Type`, Original_Availability, New_Availability, `Time`, Original_Address, New_Address, LocationID, ItemID)
	  VALUES
      (NULL, 'LOCATION_ADD',NULL, NEW.Availability, NOW(), NULL, NEW.Address, NEW.LocationID, NULL);
	END//
DELIMITER //
CREATE TRIGGER LOCATION_AVAILABILITY AFTER UPDATE ON LOCATION
	FOR EACH ROW
	BEGIN
	  INSERT INTO LOG
	  VALUES
      (
      NULL,
      'LOCATION_AVAILABILITY',
      OLD.Availability,
      NEW.Availability,
      NOW(),
      NULL,
      NULL,
      NEW.LocationID,
      NULL
      );
	END//
    
#Adds new log indicating location address was changed. 
DELIMITER //
CREATE TRIGGER LOCATION_ADDRESS AFTER UPDATE ON LOCATION
	FOR EACH ROW
	BEGIN
	  INSERT INTO LOG
	  VALUES
      (
      NULL,
      'LOCATION_ADDRESS',
      NULL,
      NULL,
      NOW(),
      OLD.Address,
      NEW.Address,
      NEW.LocationID,
      NULL
      );
	END//
    
#Adds new log indicating menu_availability was changed. 
DELIMITER //
CREATE TRIGGER MENU_AVAILABILITY AFTER UPDATE ON LOCATION_ITEM
	FOR EACH ROW
	BEGIN
	  INSERT INTO LOG
	  VALUES
      (
      NULL,
      'MENU_AVAILABILITY',
      OLD.Availability,
      NEW.Availability,
      NOW(),
      NULL,
      NULL,
      NEW.LocationID,
      NEW.ItemID
      );
	END//

#----------------------DATA-----------------------
#Adds some sample data to our database.

INSERT INTO `USER`
	VALUES	(NULL, 'example1@gmail.com', '1234', 'Todd', 'Carpenter', 'vendor'),
			(NULL, 'example2@gmail.com', '2222', 'Ted', 'Miller', 'vendor'),
            (NULL, 'example3@gmail.com', '9992', 'Tom', 'Fischer', 'vendor'),
            (NULL, 'example4@gmail.com', '5352', 'Tim', 'Wilson', 'vendor');
INSERT INTO `LOCATION`
			(LocationID, VendorName, Availability, Address, UserID, Lat, `Long`, Hours, Phone)
	VALUES	(NULL, 'Vendor1', 'Y', '95 Aurora Ave N, Seattle WA', 1, 47.608420, -122.332077, '10am - 11pm', '206-234-5678'),
			(NULL, 'Vendor2', 'Y', '105 Greenwood Ave N, Seattle WA', 2, 47.610410, -122.335329, '10am - 11pm', '206-234-5678'),
            (NULL, 'Vendor3', 'Y', '120 Greenwood Ave N, Seattle WA', 3, 47.611574, -122.334909, '10am - 11pm', '206-234-5678'),
            (NULL, 'Vendor4', 'Y', '132 Greenwood Ave N, Seattle WA', 4, 47.608078, -122.335232, '10am - 11pm', '206-234-5678');
INSERT INTO ITEM
	VALUES (NULL, 'Vegan Burger');
INSERT INTO LOCATION_ITEM
	VALUES(1,1,'Y',32),
    (2,1,'Y',53),
    (3,1,'Y',12);
INSERT INTO `ORDER`
	VALUES(NULL, 1, 'Received', '2020-01-31 23:59:59'),
			(NULL, 1, 'Received', '2020-02-02 23:59:59');
INSERT INTO Order_Item
	VALUES(1, 1, 1, 2),
		(1, 2, 1, 3);