SET @@sql_mode = REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY,', '');
------ BUSINESS CASES

-- 1. Find 5 users who have been around the longest
SELECT * FROM users ORDER BY created_at;

-- 2. What day of the week do most users register on? We need to figure out when to schedule an ad campaign
SELECT COUNT(*) AS 'Counts', DAYOFWEEK(created_at) AS 'DATE_NUMBER', DAYNAME(created_at) AS 'DATE_NAME' FROM users GROUP BY DAYOFWEEK(created_at) ORDER BY Counts DESC;

SELECT COUNT(*) AS 'Counts', DAYOFWEEK(created_at) AS 'DATE_NUMBER', 
DAYNAME(created_at) AS 'DATE_NAME' 
FROM users GROUP BY DAYOFWEEK(created_at) ORDER BY Counts DESC;


-- 3. We want to target our inactive users with an email campaign. Find the users who have never posted a photo
-- Find users never post any photos. Work with users and photos table
-- Left join will give all users and users with no photos will have nulls
SELECT * FROM users LEFT JOIN photos USING(user_id) WHERE photos.user_id IS NULL;

-- 4. Find most like photo and user who create it
SELECT photo_id, img_url, photos.user_id, user_name, COUNT(*) AS 'num_of_likes' 
FROM photos JOIN likes USING(photo_id) 
JOIN users ON photos.user_id = users.user_id 
GROUP BY photo_id ORDER BY COUNT(*) DESC;

-- 6. What are the top most commonly used hashtags?
SELECT *, COUNT(*) AS 'Count' FROM photo_tags JOIN tags USING(tag_id) GROUP BY tag_id ORDER BY Count DESC;

----7. WHAT part of day are most posts are being made

WITH hours AS (SELECT EXTRACT(Hour FROM created_at) AS hourofday, count(*) numofposts
FROM photos
GROUP BY hourofday)

SELECT sum(numofposts) AS TotalPosts,
CASE 
	WHEN hourofday >= 0 and hourofday < 6 THEN 'Dawn'
	WHEN hourofday >= 6 and hourofday < 12 THEN 'Morning'
    WHEN hourofday >= 12 and hourofday < 18 THEN 'Afternoon'
    ELSE 'Evening'
END AS PartOfDay
FROM hours
GROUP BY PartOfDay
ORDER BY TotalPosts DESC;

--- 8.WHAT part of day are most accounts being made

WITH hours AS (SELECT EXTRACT(Hour FROM created_at) AS hourofday, count(*) numofaccts
FROM users
GROUP BY hourofday)

SELECT sum(numofaccts) AS TotalAccts,
CASE 
	WHEN hourofday >= 0 and hourofday < 6 THEN 'Dawn'
	WHEN hourofday >= 6 and hourofday < 12 THEN 'Morning'
    WHEN hourofday >= 12 and hourofday < 18 THEN 'Afternoon'
    else 'Evening'
END AS PartOfDay
FROM hours
GROUP BY PartOfDay
ORDER BY TotalAccts DESC;



-- 9. FIND BOTS
-- Find users who have liked every single photo on the site
SELECT *, COUNT(*) AS 'like_count' FROM users JOIN likes USING(user_id) GROUP BY likes.user_id HAVING COUNT(*) = (SELECT COUNT(*) FROM photos);

SELECT users.user_id, users.user_name, users.created_at, COUNT(*) AS 'like_count' 
FROM users JOIN likes USING(user_id) 
GROUP BY likes.user_id HAVING COUNT(*) = (SELECT COUNT(*) FROM photos);

--10. recom
--Find what you will most likely to like(similar post) based on your like on certain photo.
--Rank list of photos which other people also liked the same photo

SELECT photo_id, COUNT(*) as 'num_likes' from likes WHERE user_id IN (SELECT likes.user_id FROM photos JOIN likes USING(photo_id) WHERE photo_id = 1) AND photo_id != 1 GROUP BY photo_id ORDER BY num_likes DESC


SELECT photo_id, COUNT(*) as 'num_likes' 
FROM likes WHERE user_id 
IN (SELECT likes.user_id FROM photos JOIN likes USING(photo_id) WHERE photo_id = 1) 
AND photo_id != 1 GROUP BY photo_id ORDER BY num_likes DESC;

-- create pocedure

DELIMITER //

CREATE PROCEDURE get_recom(in PhotoID INT)
BEGIN
SELECT photo_id, COUNT(*) as 'num_likes'
FROM likes WHERE user_id IN
(SELECT likes.user_id FROM photos JOIN likes USING(photo_id) WHERE photo_id = PhotoID)
AND photo_id != PhotoID
GROUP BY photo_id
ORDER BY num_likes DESC;
END //

DELIMITER ;

CALL get_recom(1);

