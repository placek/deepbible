import sys
import os
import re
import sqlite3
from typing import List, Tuple

class BibleAddressParser:
    def __init__(self, address: str):
        self.address = address

    def parse(self) -> List[Tuple[str, int, List[int], bool]]:
        addresses = []
        for part in self.address.split(';'):
            parsed_part = self._parse_part(part.strip())
            if parsed_part:
                addresses.append(parsed_part)
        return addresses

    def _parse_part(self, part: str) -> Tuple[str, int, List[int], bool]:
        match = re.match(r"(\w+)\s+(\d+)([\s,\d\-.]*)", part)
        if not match:
            raise ValueError(f"Could not parse part: {part}")
        book, chapter, verses = match.groups()
        chapter = int(chapter)
        verse_list, is_range_to_end = self._parse_verses(verses)
        return book, chapter, verse_list, is_range_to_end

    def _parse_verses(self, verses: str) -> Tuple[List[int], bool]:
        if len(re.findall(r',', verses)) > 1:
            raise ValueError(f"Could not parse verses: {verses}")
        verse_list = []
        is_range_to_end = False
        for segment in re.split(r'\s*[.]\s*', verses):
            cleaned_segment = re.sub(r'[^\d\-]', '', segment)
            try:
                if '-' in cleaned_segment:
                    if cleaned_segment.endswith('-'):
                        start = int(cleaned_segment[:-1])
                        verse_list.append(start)
                        is_range_to_end = True
                    else:
                        start, end = map(int, cleaned_segment.split('-'))
                        verse_list.extend(range(start, end + 1))
                elif cleaned_segment.isdigit():
                    verse_list.append(int(cleaned_segment))
            except ValueError:
                raise ValueError(f"Could not parse verses: {verses}")
        return sorted(set(verse_list)), is_range_to_end

class VersesQueryBuilder:
    def __init__(self, parsed_addresses: str):
        self.parsed_addresses = parsed_addresses
        self.table_name = "_all_verses"

    def query(self) -> str:
        queries = [self._build_query_part(book, chapter, verses, is_range_to_end)
                   for book, chapter, verses, is_range_to_end in self.parsed_addresses]
        return " UNION ALL ".join(queries) + " ORDER BY source_number, book_number, chapter, verse;"

    def _build_query_part(self, book: str, chapter: int, verses: List[int], is_range_to_end: bool) -> str:
        if is_range_to_end:
            return f"SELECT * FROM {self.table_name} WHERE book_number = (SELECT book_number FROM _books WHERE short_name = '{book}') AND chapter = {chapter} AND verse >= {verses[0]}"
        elif verses:
            verse_conditions = ', '.join(map(str, verses))
            return f"SELECT * FROM {self.table_name} WHERE book_number = (SELECT book_number FROM _books WHERE short_name = '{book}') AND chapter = {chapter} AND verse IN ({verse_conditions})"
        else:
            return f"SELECT * FROM {self.table_name} WHERE book_number = (SELECT book_number FROM _books WHERE short_name = '{book}') AND chapter = {chapter}"

class CommentariesQueryBuilder:
    def __init__(self, parsed_addresses: str):
        self.parsed_addresses = parsed_addresses
        self.table_name = "_all_commentaries"

    def query(self) -> str:
        queries = [self._build_query_part(book, chapter, verses, is_range_to_end)
                   for book, chapter, verses, is_range_to_end in self.parsed_addresses]
        return " UNION ALL ".join(queries) + " ORDER BY source_number, chapter_number_from, verse_number_from;"

    def _build_query_part(self, book: str, chapter: int, verses: List[int], is_range_to_end: bool) -> str:
        if is_range_to_end:
            return f"SELECT * FROM {self.table_name} WHERE book_number = (SELECT book_number FROM _books WHERE short_name = '{book}') AND chapter_number_from = {chapter} AND verse_number_from >= {verses[0]}"
        elif verses:
            verse_conditions = ', '.join(map(str, verses))
            return f"SELECT * FROM {self.table_name} WHERE book_number = (SELECT book_number FROM _books WHERE short_name = '{book}') AND chapter_number_from = {chapter} AND verse_number_from IN ({verse_conditions})"
        else:
            return f"SELECT * FROM {self.table_name} WHERE book_number = (SELECT book_number FROM _books WHERE short_name = '{book}') AND chapter_number_from = {chapter}"


if __name__ == "__main__":
    LANGUAGE = sys.argv[1]
    ADDRESS = sys.argv[2]
    MERGED_DIR = "merged"
    merged_db_path = os.path.join(MERGED_DIR, f"{LANGUAGE}.SQLite3")
    parser = BibleAddressParser(ADDRESS)
    connection = sqlite3.connect(merged_db_path)
    cursor = connection.cursor()
    cquery = CommentariesQueryBuilder(parser.parse()).query()

    print("Executing commentaries query:")
    print(cquery)
    cursor.execute(cquery)
    for row in cursor.fetchall():
        print(row)
    vquery = VersesQueryBuilder(parser.parse()).query()

    print("Executing verses query:")
    print(vquery)
    cursor.execute(vquery)
    for row in cursor.fetchall():
        print(row)

    connection.close()
