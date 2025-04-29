const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

const userTestController = {
  getTestForUser: async (req, res) => {
    try {
      const { testId } = req.params;

      if (!testId || isNaN(parseInt(testId))) {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowe ID testu",
        });
      }

      const test = await prisma.tests.findUnique({
        where: { id: parseInt(testId) },
        select: {
          id: true,
          title: true,
          description: true,
          time_limit: true,
          pass_threshold: true,
          chapter_id: true,
          course_id: true,
        },
      });

      if (!test) {
        return res.status(404).json({
          success: false,
          message: "Test nie został znaleziony",
        });
      }

      res.status(200).json({
        success: true,
        test: test,
      });
    } catch (error) {
      console.error("Błąd w kontrolerze getTestForUser:", error);
      res.status(500).json({
        success: false,
        message: "Wewnętrzny błąd serwera",
      });
    }
  },

  submitTestAttempt: async (req, res) => {
    try {
      const { testId } = req.params;
      const userId = req.user.id;
      const { answers } = req.body;

      const test = await prisma.tests.findUnique({
        where: { id: parseInt(testId) },
        include: {
          test_blocks: {
            include: {
              test_block_answers: true,
            },
          },
        },
      });

      if (!test) {
        return res.status(404).json({
          success: false,
          message: "Test nie został znaleziony",
        });
      }

      let correctAnswers = 0;
      let totalPoints = 0;
      let results = {};

      for (const block of test.test_blocks) {
        const userAnswer = answers[block.id];
        const blockPoints = block.points || 1;
        totalPoints += blockPoints;

        if (block.block_type === "multiple_choice") {
          const correctAnswerIds = block.test_block_answers
            .filter((a) => a.is_correct)
            .map((a) => a.id.toString());
          const userAnswerArray = Array.isArray(userAnswer)
            ? userAnswer.map((id) => id.toString())
            : [];

          const hasAllCorrectAnswers = correctAnswerIds.every((id) =>
            userAnswerArray.includes(id)
          );
          const hasNoExtraAnswers =
            userAnswerArray.length === correctAnswerIds.length;

          if (hasAllCorrectAnswers && hasNoExtraAnswers) {
            correctAnswers += blockPoints;
            results[block.id] = { correct: true, points: blockPoints };
          } else {
            results[block.id] = { correct: false, points: 0 };
          }
        } else {
          const correctAnswer = block.test_block_answers.find(
            (a) => a.is_correct
          );
          if (
            userAnswer &&
            correctAnswer &&
            userAnswer.toString() === correctAnswer.id.toString()
          ) {
            correctAnswers += blockPoints;
            results[block.id] = { correct: true, points: blockPoints };
          } else {
            results[block.id] = { correct: false, points: 0 };
          }
        }
      }

      const score = correctAnswers;

      const percentage =
        totalPoints > 0 ? Math.round((correctAnswers / totalPoints) * 100) : 0;
      const passed = percentage >= test.pass_threshold;

      const attempt = await prisma.user_test_attempts.create({
        data: {
          user_id: parseInt(userId),
          test_id: parseInt(testId),
          score,
          max_score: totalPoints > 0 ? totalPoints : 1,
          passed,
          end_time: new Date(),
        },
      });

      const userAnswersData = [];
      for (const blockId in answers) {
        if (answers[blockId]) {
          const blockIdNum = parseInt(blockId);
          const block = test.test_blocks.find((b) => b.id === blockIdNum);

          if (
            block &&
            block.block_type === "multiple_choice" &&
            Array.isArray(answers[blockId])
          ) {
            for (const answerId of answers[blockId]) {
              const answerIdNum = parseInt(answerId);
              const answer = block.test_block_answers.find(
                (a) => a.id === answerIdNum
              );
              const isCorrect = answer ? answer.is_correct : false;

              userAnswersData.push({
                attempt_id: attempt.id,
                block_id: blockIdNum,
                selected_answer_id: answerIdNum,
                is_correct: isCorrect,
              });
            }
          } else {
            const answerId = parseInt(answers[blockId]);
            const answer = block
              ? block.test_block_answers.find((a) => a.id === answerId)
              : null;
            const isCorrect = answer ? answer.is_correct : false;

            userAnswersData.push({
              attempt_id: attempt.id,
              block_id: blockIdNum,
              selected_answer_id: answerId,
              is_correct: isCorrect,
            });
          }
        }
      }

      return res.status(200).json({
        success: true,
        score,
        totalPoints: totalPoints > 0 ? totalPoints : 1,
        percentage: isFinite(percentage) ? percentage : 0,
        passed,
        testThreshold: test.pass_threshold,
      });
    } catch (error) {
      console.error(`Błąd podczas sprawdzania odpowiedzi dla testu:`, error);
      return res.status(500).json({
        success: false,
        message: "Nie udało się sprawdzić odpowiedzi",
        error: error.message,
      });
    }
  },

  getUserTestAttempts: async (req, res) => {
    try {
      const userId = req.user.id;
      const { testId } = req.params;

      console.log(`Pobieranie prób testu ${testId} dla użytkownika ${userId}`);

      if (!testId || isNaN(parseInt(testId))) {
        return res.status(400).json({
          success: false,
          message: "Nieprawidłowe ID testu",
        });
      }

      const attempts = await prisma.user_test_attempts.findMany({
        where: {
          user_id: userId,
          test_id: parseInt(testId),
        },
        include: {
          tests: {
            select: {
              title: true,
              pass_threshold: true,
              chapter_id: true,
              course_id: true,
            },
          },
          user_test_answers: true,
        },
        orderBy: {
          created_at: "desc",
        },
      });

      return res.status(200).json({
        success: true,
        attempts,
      });
    } catch (error) {
      console.error(`Błąd podczas pobierania prób: ${error}`);
      return res.status(500).json({
        success: false,
        message: "Wystąpił błąd podczas pobierania prób",
        error: error.message,
      });
    }
  },
};

module.exports = userTestController;
