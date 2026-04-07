import pygame
from settings import TILE_SIZE, PLAYER_SPEED, SCREEN_WIDTH, MAP_HEIGHT

W = 28
H = 36


class Player:
    def __init__(self, x, y):
        self.rect = pygame.Rect(x, y, W, H)
        self.facing = "down"
        self.moving = False
        self.anim_tick = 0

    def update(self, keys, tilemap):
        dx, dy = 0, 0
        if keys[pygame.K_w] or keys[pygame.K_UP]:
            dy = -PLAYER_SPEED
            self.facing = "up"
        if keys[pygame.K_s] or keys[pygame.K_DOWN]:
            dy = PLAYER_SPEED
            self.facing = "down"
        if keys[pygame.K_a] or keys[pygame.K_LEFT]:
            dx = -PLAYER_SPEED
            self.facing = "left"
        if keys[pygame.K_d] or keys[pygame.K_RIGHT]:
            dx = PLAYER_SPEED
            self.facing = "right"

        self.moving = dx != 0 or dy != 0
        if self.moving:
            self.anim_tick += 1

        # Resolve X then Y independently for smooth wall sliding
        new_rect = self.rect.move(dx, 0)
        if not tilemap.rect_collides(new_rect) and 0 <= new_rect.left and new_rect.right <= SCREEN_WIDTH:
            self.rect = new_rect

        new_rect = self.rect.move(0, dy)
        if not tilemap.rect_collides(new_rect) and 0 <= new_rect.top and new_rect.bottom <= MAP_HEIGHT:
            self.rect = new_rect

    def draw(self, surface, era):
        color = era["player"]
        r = self.rect

        # Body
        pygame.draw.rect(surface, color, r, border_radius=4)

        # Walking leg animation
        leg_color = tuple(max(0, c - 45) for c in color)
        leg_h = 10
        if self.moving and (self.anim_tick // 8) % 2 == 0:
            pygame.draw.rect(surface, leg_color,
                             pygame.Rect(r.x + 4, r.bottom - leg_h, 9, leg_h))
        else:
            pygame.draw.rect(surface, leg_color,
                             pygame.Rect(r.right - 13, r.bottom - leg_h, 9, leg_h))

        # Eyes showing facing direction
        eye = (245, 240, 210)
        if self.facing == "down":
            pygame.draw.circle(surface, eye, (r.x + 9,  r.y + 11), 3)
            pygame.draw.circle(surface, eye, (r.x + 19, r.y + 11), 3)
        elif self.facing == "up":
            pygame.draw.circle(surface, eye, (r.x + 9,  r.y + 20), 3)
            pygame.draw.circle(surface, eye, (r.x + 19, r.y + 20), 3)
        elif self.facing == "left":
            pygame.draw.circle(surface, eye, (r.x + 6, r.y + 10), 3)
            pygame.draw.circle(surface, eye, (r.x + 6, r.y + 21), 3)
        elif self.facing == "right":
            pygame.draw.circle(surface, eye, (r.right - 6, r.y + 10), 3)
            pygame.draw.circle(surface, eye, (r.right - 6, r.y + 21), 3)
