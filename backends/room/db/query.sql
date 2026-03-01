-- name: GetRoomById :one
SELECT * FROM rooms
WHERE id = $1;

-- name: CreateRoom :one
INSERT INTO rooms (name)
VALUES ($1)
RETURNING *;

-- name: DeleteRoom :exec
DELETE FROM rooms
WHERE id = $1;

-- name: AddRoomMember :exec
INSERT INTO room_members (room_id, user_id)
VALUES ($1, $2);

-- name: RemoveRoomMember :exec
DELETE FROM room_members
WHERE room_id = $1 AND user_id = $2;