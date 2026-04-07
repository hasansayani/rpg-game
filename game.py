import sys
import pygame
from settings import (TITLE, SCREEN_WIDTH, SCREEN_HEIGHT, MAP_HEIGHT,
                      UI_HEIGHT, TILE_SIZE, FPS)
from era import EraManager
from tilemap import TileMap
from player import Player
from npc import NPC
from dialogue import DialogueSystem


class Game:
    def __init__(self):
        self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
        pygame.display.set_caption(TITLE)
        self.clock = pygame.time.Clock()

        self.fonts = {
            "bold":      pygame.font.SysFont("Georgia", 18, bold=True),
            "body":      pygame.font.SysFont("Georgia", 16),
            "small":     pygame.font.SysFont("Georgia", 13),
            "hud":       pygame.font.SysFont("Georgia", 14),
            "era_title": pygame.font.SysFont("Georgia", 34, bold=True),
            "era_sub":   pygame.font.SysFont("Georgia", 16),
        }

        self.era_manager = EraManager()
        self.tilemap     = TileMap()
        self.player      = Player(3 * TILE_SIZE, 5 * TILE_SIZE)
        self.npc         = NPC(tile_col=9, tile_row=5, name="Maren")
        self.dialogue    = DialogueSystem()

    # ------------------------------------------------------------------
    def run(self):
        while True:
            self._handle_events()
            self._update()
            self._draw()
            self.clock.tick(FPS)

    # ------------------------------------------------------------------
    def _handle_events(self):
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    pygame.quit()
                    sys.exit()

                if event.key == pygame.K_TAB:
                    if not self.dialogue.active:
                        self.era_manager.cycle()

                if event.key == pygame.K_e:
                    if self.dialogue.active:
                        self.dialogue.advance()
                    elif self.npc.is_near(self.player):
                        lines = self.npc.get_dialogue(self.era_manager.era_key)
                        self.dialogue.start(self.npc.name, lines)

    # ------------------------------------------------------------------
    def _update(self):
        if not self.dialogue.active and not self.era_manager.transitioning:
            keys = pygame.key.get_pressed()
            self.player.update(keys, self.tilemap)

        self.npc.update()
        self.dialogue.update()
        self.era_manager.update()

    # ------------------------------------------------------------------
    def _draw(self):
        era = self.era_manager.era
        self.screen.fill(era["bg"])

        self.tilemap.draw(self.screen, era)

        near = self.npc.is_near(self.player)
        self.npc.draw(self.screen, era)
        self.npc.draw_interact_hint(self.screen, self.fonts["small"], near)

        self.player.draw(self.screen, era)

        # Color tint + flash overlay
        self.era_manager.draw_overlay(self.screen)

        # Dialogue box sits on top of overlay
        self.dialogue.draw(self.screen, self.fonts, era)

        self._draw_hud(era)

        if self.era_manager.announcing:
            self._draw_era_announcement(era)

        pygame.display.flip()

    def _draw_hud(self, era):
        hud_y = MAP_HEIGHT + 4
        hud_rect = pygame.Rect(8, hud_y, SCREEN_WIDTH - 16, UI_HEIGHT - 8)

        bg = pygame.Surface((hud_rect.width, hud_rect.height), pygame.SRCALPHA)
        bg.fill((*era["ui_bg"], 200))
        self.screen.blit(bg, hud_rect.topleft)
        pygame.draw.rect(self.screen, era["hud_era"], hud_rect, 1, border_radius=4)

        era_text = self.fonts["hud"].render(f"Era:  {era['name']}", True, era["hud_era"])
        self.screen.blit(era_text, (hud_rect.x + 12, hud_rect.y + 8))

        ctrl = self.fonts["hud"].render(
            "WASD / Arrows: Move   |   TAB: Shift Era   |   E: Interact   |   ESC: Quit",
            True, era["ui_text"],
        )
        self.screen.blit(ctrl, (hud_rect.x + 12, hud_rect.y + 30))

    def _draw_era_announcement(self, era):
        alpha = self.era_manager.announce_alpha
        cx = SCREEN_WIDTH // 2
        cy = MAP_HEIGHT // 3

        title_surf = self.fonts["era_title"].render(era["name"], True, era["hud_era"])
        sub_surf   = self.fonts["era_sub"].render(era["subtitle"], True, era["ui_text"])

        title_rect = title_surf.get_rect(center=(cx, cy))
        sub_rect   = sub_surf.get_rect(center=(cx, cy + 46))

        # Dark pill backdrop
        pad = 20
        backdrop_w = max(title_rect.width, sub_rect.width) + pad * 2
        backdrop = pygame.Surface((backdrop_w, 88), pygame.SRCALPHA)
        backdrop.fill((0, 0, 0, int(alpha * 0.55)))
        self.screen.blit(backdrop, (cx - backdrop_w // 2, cy - 26))

        title_surf.set_alpha(alpha)
        sub_surf.set_alpha(alpha)
        self.screen.blit(title_surf, title_rect)
        self.screen.blit(sub_surf, sub_rect)
