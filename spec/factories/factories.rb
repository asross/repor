FactoryBot.define do
  factory :author do
    name { Faker::Name.name }
  end

  factory :comment do
    transient { author { nil } }

    before(:create) do |record, evaluator|
      if evaluator.author
        author = Author.find_or_create_by(name: evaluator.author)
        record.author_id = author.id
      end
    end
  end

  
  factory :post do
    status { :published }
    transient { author { nil } }

    before(:create) do |record, evaluator|
      if evaluator.author
        author = Author.find_or_create_by(name: evaluator.author)
        record.author_id = author.id
      end
    end
  end
end
