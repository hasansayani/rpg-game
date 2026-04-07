import pygame
from settings import ERAS, ERA_ORDER, SCREEN_WIDTH, SCREEN_HEIGHT


class EraManager:
    ANNOUNCE_DURATION = 180  # frames (3s at 60fps)
    FLASH_SPEED = 15

    def __init__(self):
        self.current_idx = 0
        self.transitioning = False
        self.transition_alpha = 0
        self.transition_dir = 1   # 1 = fading up to white, -1 = fading back
        self.flash_surface = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT))
        self.flash_surface.fill((255, 255, 255))
        self.announce_timer = 0

    @property
    def era_key(self):
        return ERA_ORDER[self.current_idx]

    @property
    def era(self):
        return ERAS[self.era_key]

    def cycle(self):
        if not self.transitioning:
            self.transitioning = True
            self.transition_alpha = 0
            self.transition_dir = 1

    def update(self):
        if self.transitioning:
            self.transition_alpha += self.transition_dir * self.FLASH_SPEED
            if self.transition_dir == 1 and self.transition_alpha >= 255:
                self.transition_alpha = 255
                self.current_idx = (self.current_idx + 1) % len(ERA_ORDER)
                self.transition_dir = -1
                self.announce_timer = self.ANNOUNCE_DURATION
            elif self.transition_dir == -1 and self.transition_alpha <= 0:
                self.transition_alpha = 0
                self.transitioning = False

        if self.announce_timer > 0:
            self.announce_timer -= 1

    def draw_overlay(self, surface):
        # Per-era color tint
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill(self.era["overlay"])
        surface.blit(overlay, (0, 0))

        # White flash during transition
        if self.transitioning and self.transition_alpha > 0:
            self.flash_surface.set_alpha(int(self.transition_alpha))
            surface.blit(self.flash_surface, (0, 0))

    @property
    def announcing(self):
        return self.announce_timer > 0

    @property
    def announce_alpha(self):
        t = self.announce_timer
        if t > self.ANNOUNCE_DURATION - 20:
            return int(255 * (self.ANNOUNCE_DURATION - t) / 20)
        if t < 40:
            return int(255 * t / 40)
        return 255
