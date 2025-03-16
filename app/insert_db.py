#!/usr/bin/env python3

import os
import sys
import time
import argparse
import psycopg2
import logging
from faker import Faker
from tqdm import tqdm
import random
from psycopg2.extras import execute_values

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

DB_HOST = os.environ.get('DB_HOST_1')
DB_PORT = os.environ.get('DB_PORT')
DB_NAME = os.environ.get('DB_NAME')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')

fake = Faker()


def generate_random_book():
    isbn = f"{random.randint(1000000000000, 9999999999999)}"

    return {
        'category_id': random.randint(1, 100),
        'title': fake.catch_phrase(),
        'author': fake.name(),
        'isbn': isbn,
        'year': random.randint(1900, 2025),
    }


def insert_books(num_books, batch_size=1000):
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )

        cur = conn.cursor()

        start_time = time.time()
        total_inserted = 0

        for i in range(0, num_books, batch_size):
            current_batch_size = min(batch_size, num_books - i)

            books_batch = [generate_random_book() for _ in range(current_batch_size)]

            columns = ['category_id', 'title', 'author', 'isbn', 'year']
            values = [[book[column] for column in columns] for book in books_batch]

            query = f"""
                INSERT INTO books (category_id, title, author, isbn, year)
                VALUES %s
            """

            execute_values(cur, query, values)

            conn.commit()

            total_inserted += current_batch_size
            logger.info(f"Inserted batch of {current_batch_size} books (Total: {total_inserted}/{num_books})")

        end_time = time.time()
        elapsed_time = end_time - start_time

        logger.info(f"Successfully inserted {num_books} books in {elapsed_time:.2f} seconds")
        logger.info(f"Average insertion rate: {num_books / elapsed_time:.2f} books per second")

        print(f"\n--- Insertion Summary ---")
        print(f"Total books inserted: {num_books}")
        print(f"Batch size: {batch_size}")
        print(f"Total time: {elapsed_time:.2f} seconds")
        print(f"Average rate: {num_books / elapsed_time:.2f} books per second")

    except Exception as e:
        logger.error(f"Error inserting books: {e}")
        if conn:
            conn.rollback()
        raise
    finally:
        if cur:
            cur.close()
        if conn:
            conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Insert random books into the database')
    parser.add_argument('num_books', type=int, help='Number of books to insert')
    parser.add_argument('--batch-size', type=int, default=1000, help='Batch size for insertion (default: 1000)')

    args = parser.parse_args()

    logger.info(f"Starting data insertion: {args.num_books} books with batch size {args.batch_size}")
    insert_books(args.num_books, args.batch_size)