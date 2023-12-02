-- QUESTION 1 --
CREATE VIEW actor_minutes AS
SELECT actor_episode.actor_id AS ID,  SUM(user_history.minutes_played) AS total_minutes_played
FROM user_history
JOIN actor_episode USING(episode_id)
GROUP BY  actor_episode.actor_id;



-- QUESTION 2 --
CREATE VIEW series_actors AS
SELECT s.series_id, GROUP_CONCAT(DISTINCT a.actor_name ORDER BY a.actor_name ASC) AS cast
FROM series s
LEFT JOIN episodes e ON s.series_id = e.series_id
LEFT JOIN actor_episode ae ON e.episode_id = ae.episode_id
LEFT JOIN actors a ON ae.actor_id = a.actor_id
GROUP BY s.series_id;

CREATE VIEW top_series_cast AS
SELECT s.series_id, s.series_title, sa.cast
FROM series s
JOIN series_actors sa ON s.series_id = sa.series_id
WHERE s.rating >= 4.00;



-- QUESTION 3 --
DELIMITER $$
CREATE TRIGGER AdjustRating 
BEFORE INSERT ON user_history
FOR EACH ROW
BEGIN
    SET NEW.minutes_played = LEAST(NEW.minutes_played, (SELECT episode_length 
                                                        FROM episodes 
                                                        WHERE episode_id = NEW.episode_id));
    
    SET @new_rating_adjustment = 0.0001 * NEW.minutes_played;

    SET @current_rating = (SELECT rating 
                           FROM series 
                           WHERE series_id = (SELECT series_id 
                                              FROM episodes
                                              WHERE episode_id = NEW.episode_id));

    
    IF @current_rating + @new_rating_adjustment > 5.00 THEN
        SET @new_rating_adjustment = 5.00 - @current_rating;
    END IF;

    SET NEW.minutes_played = NEW.minutes_played;
    
    UPDATE series
    SET rating = LEAST(5.00, @current_rating + @new_rating_adjustment)
    WHERE series_id = (SELECT series_id 
                       FROM episodes 
                       WHERE episode_id = NEW.episode_id);
END$$
DELIMITER ;



-- QUESTION 4 --
DELIMITER $$
CREATE PROCEDURE AddEpisode(
    IN s_id INTEGER(10),
    IN s_number TINYINT(4),
    IN e_number TINYINT(4),
    IN e_title VARCHAR(128),
    IN e_length REAL
)
ae: BEGIN
    DECLARE series_count INT;
    DECLARE episode_count INT;
    DECLARE e_id INT;

    SELECT COUNT(*) INTO series_count FROM series WHERE series_id = s_id;
    IF series_count < 1 THEN
        SELECT 'No series with same ID.' as ' ';
        LEAVE ae;
    END IF;

    SELECT COUNT(*) INTO episode_count FROM episodes WHERE episode_number = e_number AND season_number = s_number AND series_id = s_id;
    IF episode_count > 0 THEN
        SELECT 'Episode already exists.' as ' ';
        LEAVE ae;
    END IF;

    SET e_id = 100000;
    WHILE (SELECT COUNT(*) FROM episodes WHERE episode_id = e_id) > 0 DO
        SET e_id = FLOOR(RAND() * (1000000 - 100000 + 1) + 100000);
    END WHILE;

    INSERT INTO episodes (
        episode_id,
        series_id,
        season_number,
        episode_number,
        episode_title,
        episode_length,
        date_of_release
    )
    VALUES (
        e_id,
        s_id,
        s_number,
        e_number,
        e_title,
        e_length,
        CURDATE()
    );
END ae$$
DELIMITER ;



-- QUESTION 5 --
DELIMITER $$
CREATE FUNCTION `GetEpisodeList`(`s_id` INT, `s_number` TINYINT) 
RETURNS varchar(1024) CHARSET utf8mb4 COLLATE utf8mb4_general_ci
BEGIN
DECLARE episode_list varchar(1000);
SELECT GROUP_CONCAT(episode_title ORDER BY episode_number ASC SEPARATOR ', ')
INTO episode_list
FROM episodes
WHERE series_id = s_id AND season_number = s_number;
RETURN episode_list;
END$$
DELIMITER ;