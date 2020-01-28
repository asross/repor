class DataBuilder
  class << self
    def gaussian(mean, stddev)
      theta = 2 * Math::PI * Random.new.rand
      rho = Math.sqrt(-2 * Math.log(1 - Random.new.rand))
      scale = stddev * rho
      return [0, mean + scale * Math.cos(theta)].max
    end

    def random_title
      if rand < 0.5
        "#{Faker::Hacker.ingverb} #{Faker::Hacker.adjective} #{Faker::Hacker.noun}"
      else
        Faker::Book.title
      end
    end

    def build!
      Post.destroy_all
      Comment.destroy_all
      Author.destroy_all

      authors = ([
        "Shay Sides",
        "Teodoro Rainey",
        "Norman Hanley",
        "Raleigh Townes",
        "Samatha Doan",
        "Valeria Seward",
        "Jewel Cervantes",
        "Fallon Clapp",
        "Kenna Marlow",
        "Maurine Butterfield",
        "Teresa Gonzales",
        "Becky Silva",
        "Frank Robertson",
        "Alex Hamilton",
        "Emilio Powell",
        "Jerry Zimmerman",
      ] + 20.times.map { Faker::Name.name }).map do |name|
        Author.create!(name: name)
      end

      titles = [
        "The 17 Cutest Ways To Eat A Burrito Of The Post-Y2K Era",
        "22 Problems Only Cover Bands Will Understand",
        "The 26 Most Beloved Things Of The '80s",
        "The 18 Greatest Facts Of 2013",
        "39 Real Estate Moguls Who Absolutely Nailed It In 2013",
        "34 Painful Truths Only NFL Linebackers Will Understand",
        "The 43 Most Important Punctuation Marks In South America",
        "The 25 Most Picturesque HBO Shows Of The Last 10 Years",
        "The 45 Best Oprah-Grams From The Ocean Floor",
        "20 Tweets That Look Like Miley Cyrus",
        "The 44 iPhone Apps That Look Like Channing Tatum",
        "The 14 Most Wanted Truths Of All Time",
        "The 37 Most Courageous Horses Of The '90s"
      ] + 1000.times.map { random_title }

      author_likeability = authors.each_with_object({}) do |author, h|
        average_likes = gaussian(10, 5)
        stddev_likes = gaussian(10, 2.5)
        h[author] = [average_likes, stddev_likes]
      end
      
      likeability_for = Hash.new { |h, author|
        h[author] = Hash.new { |hh, title|
          l = author_likeability[author]
          hh[title] = [l[0] * (1+rand), l[1]]
        }
      }

      titles.each do |title|
        if rand < 0.5
          author = authors.sample
        else
          author_index = gaussian(authors.length/2, authors.length/4).to_i
          author = authors[author_index % authors.length]
        end

        post = Post.create!(
          title: title,
          created_at: gaussian(100, 40).days.ago,
          likes: gaussian(*likeability_for[author][title]).to_i,
          author: author,
          status: :published
        )

        gaussian(8, 4).to_i.times do
          Comment.create!(post: post, likes: gaussian(5, 2).to_i, author: authors.sample, created_at: post.created_at + gaussian(10, 5).days)
        end
      end
    end
  end
end
