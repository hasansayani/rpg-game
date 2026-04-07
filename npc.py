import math
import pygame
from settings import TILE_SIZE, NPC_DIALOGUE

W = 28
H = 36
INTERACT_RADIUS = 64


class NPC:
    def __init__(self, tile_col, tile_row, name="Maren"):
        px = tile_col * TILE_SIZE + (TILE_SIZE - W) // 2
        py = tile_row * TILE_SIZE + (TILE_SIZE - H) // 2
        self.rect = pygame.Rect(px, py, W, H)
        self.name = name
        self.bob_tick = 0
        self.bob_offset = 0

    def update(self):
        self.bob_tick += 1
        self.bob_offset = int(math.sin(self.bob_tick * 0.05) * 3)

    def is_near(self, player):
        dx = self.rect.centerx - player.rect.centerx
        dy = self.rect.centery - player.rect.centery
        return math.hypot(dx, dy) < INTERACT_RADIUS

    def draw(self, surface, era):
        color = era["npc"]
        r = self.rect.move(0, self.bob_offset)

        # Body / cloak
        pygame.draw.rect(surface, color, r, border_radius=4)

        # Darker robe hem at the bottom
        hem = tuple(max(0, c - 35) for c in color)
        pygame.draw.rect(surface, hem,
                         pygame.Rect(r.x, r.bottom - 14, r.width, 14), border_radius=3)

        # Eyes
        eye = (245, 240, 200)
        pygame.draw.circle(surface, eye, (r.x + 9,  r.y + 11), 3)
        pygame.draw.circle(surface, eye, (r.x + 19, r.y + 11), 3)

    def draw_interact_hint(self, surface, font, near):
        if near:
            text = font.render("[E] Talk", True, (255, 255, 160))
            x = self.rect.centerx - text.get_width() // 2
            y = self.rect.top - 22 + self.bob_offset
            surface.blit(text, (x, y))

    def get_dialogue(self, era_key):
        return NPC_DIALOGUE.get(era_key, ["..."])
