import pygame
from settings import SCREEN_WIDTH, SCREEN_HEIGHT

BOX_PAD = 16
BOX_HEIGHT = 104
CHAR_DELAY = 2   # frames between characters (typewriter speed)


class DialogueSystem:
    def __init__(self):
        self.active = False
        self.lines = []
        self.line_idx = 0
        self.speaker = ""
        self.char_idx = 0
        self.char_timer = 0

    def start(self, speaker, lines):
        self.active = True
        self.speaker = speaker
        self.lines = lines
        self.line_idx = 0
        self.char_idx = 0
        self.char_timer = 0

    def advance(self):
        if not self.active:
            return
        current = self.lines[self.line_idx]
        if self.char_idx < len(current):
            self.char_idx = len(current)   # skip to end of line
        else:
            self.line_idx += 1
            if self.line_idx >= len(self.lines):
                self.active = False
            else:
                self.char_idx = 0
                self.char_timer = 0

    def update(self):
        if not self.active:
            return
        current = self.lines[self.line_idx]
        if self.char_idx < len(current):
            self.char_timer += 1
            if self.char_timer >= CHAR_DELAY:
                self.char_timer = 0
                self.char_idx += 1

    def draw(self, surface, fonts, era):
        if not self.active:
            return

        box_y = SCREEN_HEIGHT - BOX_HEIGHT - 8
        box_rect = pygame.Rect(BOX_PAD, box_y, SCREEN_WIDTH - BOX_PAD * 2, BOX_HEIGHT)

        # Semi-transparent background
        bg = pygame.Surface((box_rect.width, box_rect.height), pygame.SRCALPHA)
        bg.fill((*era["ui_bg"], 220))
        surface.blit(bg, box_rect.topleft)

        # Border
        pygame.draw.rect(surface, era["hud_era"], box_rect, 2, border_radius=6)

        # Speaker name
        name_surf = fonts["bold"].render(self.speaker, True, era["hud_era"])
        surface.blit(name_surf, (box_rect.x + BOX_PAD, box_rect.y + BOX_PAD))

        # Typewriter text
        current = self.lines[self.line_idx]
        visible = current[:self.char_idx]
        text_surf = fonts["body"].render(visible, True, era["ui_text"])
        surface.blit(text_surf, (box_rect.x + BOX_PAD, box_rect.y + BOX_PAD + 30))

        # Blinking "press E" prompt when line is complete
        if self.char_idx >= len(current):
            blink = (pygame.time.get_ticks() // 500) % 2 == 0
            if blink:
                prompt = fonts["small"].render("Press E to continue", True, era["hud_era"])
                surface.blit(prompt, (
                    box_rect.right - prompt.get_width() - BOX_PAD,
                    box_rect.bottom - prompt.get_height() - BOX_PAD,
                ))
