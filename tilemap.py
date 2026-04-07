import pygame
from settings import TILE_SIZE, MAP_DATA, FLOOR, WALL, WATER


class TileMap:
    def __init__(self):
        self.data = MAP_DATA
        self.rows = len(self.data)
        self.cols = len(self.data[0])

    def draw(self, surface, era):
        for row in range(self.rows):
            for col in range(self.cols):
                tile = self.data[row][col]
                x = col * TILE_SIZE
                y = row * TILE_SIZE
                rect = pygame.Rect(x, y, TILE_SIZE, TILE_SIZE)

                if tile == WALL:
                    color = era["wall"]
                    pygame.draw.rect(surface, color, rect)
                    # Top highlight for fake depth
                    lighter = tuple(min(255, c + 25) for c in color)
                    pygame.draw.line(surface, lighter, (x, y), (x + TILE_SIZE, y), 2)
                    pygame.draw.line(surface, lighter, (x, y), (x, y + TILE_SIZE), 2)

                elif tile == WATER:
                    color = era["water"]
                    pygame.draw.rect(surface, color, rect)
                    # Animated shimmer stripe
                    tick = pygame.time.get_ticks() // 600
                    stripe_y = y + ((tick * 8 + col * 5) % (TILE_SIZE - 6))
                    lighter = tuple(min(255, c + 35) for c in color)
                    pygame.draw.rect(surface, lighter,
                                     pygame.Rect(x + 4, stripe_y, TILE_SIZE - 8, 3))

                else:  # FLOOR
                    color = era["floor"]
                    pygame.draw.rect(surface, color, rect)
                    # Subtle grid line
                    darker = tuple(max(0, c - 10) for c in color)
                    pygame.draw.rect(surface, darker, rect, 1)

    def _tile_at(self, pixel_x, pixel_y):
        col = int(pixel_x // TILE_SIZE)
        row = int(pixel_y // TILE_SIZE)
        if row < 0 or row >= self.rows or col < 0 or col >= self.cols:
            return WALL
        return self.data[row][col]

    def rect_collides(self, rect):
        corners = [
            (rect.left + 2,  rect.top + 2),
            (rect.right - 2, rect.top + 2),
            (rect.left + 2,  rect.bottom - 2),
            (rect.right - 2, rect.bottom - 2),
        ]
        return any(self._tile_at(cx, cy) in (WALL, WATER) for cx, cy in corners)
