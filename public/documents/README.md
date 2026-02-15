# Documents Directory

This directory contains downloadable resources for the application.

## Setup Instructions

After cloning the repository, download the following files:

### 1. Tips for Sharing Impactful Stories PDF

Download from cloudinary and place in this directory:

```bash
curl -L "https://res.cloudinary.com/a-window-between-worlds/image/upload/v1750730476/Tips_for_Sharing_Impactful_Stories_lkuime.pdf" -o public/documents/tips_for_sharing_impactful_stories.pdf
```

Original URL: https://res.cloudinary.com/a-window-between-worlds/image/upload/v1750730476/Tips_for_Sharing_Impactful_Stories_lkuime.pdf

### 2. Info Icon

Download the info icon and place in `public/images/`:

```bash
curl -L "https://stories.awbw.org/wp-content/uploads/2021/08/info-1.png" -o public/images/info-icon.png
```

Original URL: https://stories.awbw.org/wp-content/uploads/2021/08/info-1.png

## Usage

These files are referenced in the story ideas form (`app/views/story_ideas/_form.html.erb`) to provide helpful tips to users when sharing stories.
